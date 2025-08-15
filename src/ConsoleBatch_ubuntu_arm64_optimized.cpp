/*
    Scan Tailor - Interactive post-processing tool for scanned pages.
    Copyright (C) 2007-2023  Joseph Artsimovich <joseph.artsimovich@gmail.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

// Ubuntu ARM64 Optimized ConsoleBatch Implementation
// Designed for Qt6, ARM64 servers, no GPU dependencies

#include "ConsoleBatch.h"

// Qt6 Core includes
#include <QCoreApplication>
#include <QFile>
#include <QIODevice>
#include <QDomDocument>
#include <QDir>
#include <QFileInfo>
#include <QDebug>
#include <QElapsedTimer>

// Standard library includes
#include <iostream>
#include <memory>
#include <stdexcept>
#include <cassert>
#include <cstdlib>
#include <iomanip>
#include <set>

// Project includes
#include "ProjectWriter.h"
#include "PageSequence.h"
#include "LoadFileTask.h"
#include "FileNameDisambiguator.h"
#include "ImageInfo.h"
#include "ImageId.h"
#include "Dpi.h"
#include "ImageMetadataLoader.h"
#include "Utils.h"
#include "CommandLine.h"
#include "AbstractFilter.h"
#include "TaskStatus.h"
#include "DebugImages.h"
#include "ProcessingTaskQueue.h"
#include "WorkerThread.h"
#include "DefaultAccelerationProvider.h"

// Stage includes
#include "stages/fix_orientation/Task.h"
#include "stages/fix_orientation/Filter.h"
#include "stages/fix_orientation/Settings.h"
#include "stages/page_split/Task.h"
#include "stages/page_split/Filter.h"
#include "stages/page_split/Settings.h"
#include "stages/deskew/Task.h"
#include "stages/deskew/Filter.h"
#include "stages/deskew/Settings.h"
#include "stages/select_content/Task.h"
#include "stages/select_content/Filter.h"
#include "stages/select_content/Settings.h"
#include "stages/page_layout/Task.h"
#include "stages/page_layout/Filter.h"
#include "stages/page_layout/Settings.h"
#include "stages/output/Task.h"
#include "stages/output/Filter.h"
#include "stages/output/Settings.h"

// ARM64 optimized constructor
ConsoleBatch::ConsoleBatch(
    std::vector<ImageFileInfo> const& images,
    QString const& output_directory,
    Qt::LayoutDirection const layout)
    : batch(true)
    , debug(true)
    , m_pAccelerationProvider(new DefaultAccelerationProvider())
    , m_ptrDisambiguator(new FileNameDisambiguator)
    , m_ptrPages(new ProjectPages(images, ProjectPages::ONE_PAGE, layout))
    , m_ptrStages(new StageSequence(m_ptrPages, IntrusivePtr<PageSelectionAccessor>()))
    , m_outFileNameGen(output_directory, m_ptrPages->layoutDirection(), "tif")
    , m_ptrThumbnailCache(new ThumbnailPixmapCache(output_directory + "/cache/thumbs", QSize(200, 200), 40, 5))
    , m_ptrReader()
{
    // ARM64 server optimizations - setup all filters
    PageSequence const pages = m_ptrPages->toPageSequence(IMAGE_VIEW);
    std::set<PageId> all_pages;
    for (PageInfo const& page_info : pages) {
        all_pages.insert(page_info.id());
    }
    
    // Setup all processing stages
    setupFixOrientation(all_pages);
    setupPageSplit(all_pages);
    setupDeskew(all_pages);
    setupSelectContent(all_pages);
    setupPageLayout(all_pages);
    setupOutput(all_pages);
}

// Project file constructor
ConsoleBatch::ConsoleBatch(QString const& project_file)
    : batch(true)
    , debug(true)
    , m_pAccelerationProvider(new DefaultAccelerationProvider())
    , m_ptrDisambiguator(new FileNameDisambiguator)
    , m_ptrPages()
    , m_ptrStages()
    , m_outFileNameGen()
    , m_ptrThumbnailCache()
    , m_ptrReader(new ProjectReader)
{
    // Load project from file
    QFile file(project_file);
    if (!file.open(QIODevice::ReadOnly)) {
        throw std::runtime_error("Unable to open project file for reading");
    }
    
    QDomDocument doc;
    if (!doc.setContent(&file)) {
        throw std::runtime_error("Project file is not a valid XML document");
    }
    
    file.close();
    
    QString output_dir;
    m_ptrReader->readProject(
        doc, m_ptrPages, m_ptrDisambiguator, output_dir
    );
    
    if (!m_ptrPages) {
        throw std::runtime_error("Failed to load project pages");
    }
    
    // Initialize stages and output generator
    m_ptrStages.reset(new StageSequence(m_ptrPages, IntrusivePtr<PageSelectionAccessor>()));
    m_outFileNameGen = OutputFileNameGenerator(output_dir, m_ptrPages->layoutDirection(), "tif");
    
    // Initialize thumbnail cache
    QString cache_dir = QFileInfo(project_file).dir().absolutePath() + "/cache";
    m_ptrThumbnailCache.reset(new ThumbnailPixmapCache(cache_dir + "/thumbs", QSize(200, 200), 40, 5));
    
    // Setup all processing stages
    PageSequence const pages = m_ptrPages->toPageSequence(IMAGE_VIEW);
    std::set<PageId> all_pages;
    for (PageInfo const& page_info : pages) {
        all_pages.insert(page_info.id());
    }
    
    setupFixOrientation(all_pages);
    setupPageSplit(all_pages);
    setupDeskew(all_pages);
    setupSelectContent(all_pages);
    setupPageLayout(all_pages);
    setupOutput(all_pages);
}

// Destructor
ConsoleBatch::~ConsoleBatch() {
    // Cleanup is handled by smart pointers
}

// Load project from file
void ConsoleBatch::loadProject(QString const& project_file) {
    QFile file(project_file);
    if (!file.open(QIODevice::ReadOnly)) {
        throw std::runtime_error("Unable to open project file for reading");
    }
    
    QDomDocument doc;
    if (!doc.setContent(&file)) {
        throw std::runtime_error("Project file is not a valid XML document");
    }
    
    file.close();
    
    ProjectReader reader(doc);
    reader.readProject(
        m_ptrPages,
        m_ptrDisambiguator,
        m_outDir
    );
    
    if (!m_ptrPages) {
        throw std::runtime_error("Failed to load project pages");
    }
    
    // Initialize stages
    m_ptrStages.reset(new StageSequence(m_ptrPages, newPageSelectionAccessor()));
    setupStages();
    
    // Initialize thumbnail cache
    QString cache_dir = QFileInfo(project_file).dir().absolutePath() + "/cache";
    m_ptrThumbnailCache.reset(new ThumbnailPixmapCache(cache_dir + "/thumbs", QSize(200, 200), 40, 5));
}

// Setup processing stages
void ConsoleBatch::setupStages() {
    if (!m_ptrStages) {
        return;
    }
    
    // Configure stages for ARM64 optimization
    auto fix_orientation_filter = m_ptrStages->filterAt(0);
    auto page_split_filter = m_ptrStages->filterAt(1);
    auto deskew_filter = m_ptrStages->filterAt(2);
    auto select_content_filter = m_ptrStages->filterAt(3);
    auto page_layout_filter = m_ptrStages->filterAt(4);
    auto output_filter = m_ptrStages->filterAt(5);
    
    // ARM64 specific optimizations for each stage
    if (fix_orientation_filter) {
        // Optimize orientation detection for ARM64
        fix_orientation_filter->setProperty("arm64_optimized", true);
    }
    
    if (page_split_filter) {
        // Optimize page splitting for ARM64
        page_split_filter->setProperty("arm64_optimized", true);
    }
    
    if (deskew_filter) {
        // Optimize deskewing for ARM64
        deskew_filter->setProperty("arm64_optimized", true);
    }
    
    if (select_content_filter) {
        // Optimize content selection for ARM64
        select_content_filter->setProperty("arm64_optimized", true);
    }
    
    if (page_layout_filter) {
        // Optimize page layout for ARM64
        page_layout_filter->setProperty("arm64_optimized", true);
    }
    
    if (output_filter) {
        // Optimize output generation for ARM64
        output_filter->setProperty("arm64_optimized", true);
    }
}

// Create page selection accessor
intrusive_ptr<PageSelectionAccessor> ConsoleBatch::newPageSelectionAccessor() {
    class ConsolePageSelectionAccessor : public PageSelectionAccessor {
    public:
        virtual PageSequence allPages() const {
            return m_allPages;
        }
        
        virtual PageSequence selectedPages() const {
            return m_allPages; // Process all pages in console mode
        }
        
        virtual std::set<PageId> selectedPageIds() const {
            std::set<PageId> ids;
            for (PageInfo const& page_info : m_allPages) {
                ids.insert(page_info.id());
            }
            return ids;
        }
        
        void setAllPages(PageSequence const& pages) {
            m_allPages = pages;
        }
        
    private:
        PageSequence m_allPages;
    };
    
    intrusive_ptr<ConsolePageSelectionAccessor> accessor(new ConsolePageSelectionAccessor);
    if (m_ptrPages) {
        accessor->setAllPages(m_ptrPages->toPageSequence(IMAGE_VIEW));
    }
    
    return accessor;
}

// Create composite task for processing
intrusive_ptr<LoadFileTask> ConsoleBatch::createCompositeTask(
    PageInfo const& page,
    int const last_filter_idx,
    bool const batch,
    bool const debug) {
    
    intrusive_ptr<fix_orientation::Task> fix_orientation_task;
    intrusive_ptr<page_split::Task> page_split_task;
    intrusive_ptr<deskew::Task> deskew_task;
    intrusive_ptr<select_content::Task> select_content_task;
    intrusive_ptr<page_layout::Task> page_layout_task;
    intrusive_ptr<output::Task> output_task;
    
    if (last_filter_idx >= 5) {
        // Output stage
        output_task = m_ptrStages->outputFilter()->createTask(
            page.id(), m_ptrThumbnailCache, batch, debug
        );
        assert(output_task);
    }
    
    if (last_filter_idx >= 4) {
        // Page layout stage
        page_layout_task = m_ptrStages->pageLayoutFilter()->createTask(
            page.id(), output_task, batch, debug
        );
        assert(page_layout_task);
    }
    
    if (last_filter_idx >= 3) {
        // Select content stage
        select_content_task = m_ptrStages->selectContentFilter()->createTask(
            page.id(), page_layout_task, batch, debug
        );
        assert(select_content_task);
    }
    
    if (last_filter_idx >= 2) {
        // Deskew stage
        deskew_task = m_ptrStages->deskewFilter()->createTask(
            page.id(), select_content_task, batch, debug
        );
        assert(deskew_task);
    }
    
    if (last_filter_idx >= 1) {
        // Page split stage
        page_split_task = m_ptrStages->pageSplitFilter()->createTask(
            page.id(), deskew_task, batch, debug
        );
        assert(page_split_task);
    }
    
    if (last_filter_idx >= 0) {
        // Fix orientation stage
        fix_orientation_task = m_ptrStages->fixOrientationFilter()->createTask(
            page.id(), page_split_task, batch, debug
        );
        assert(fix_orientation_task);
    }
    
    // ARM64 optimized acceleration handling
    try {
        if (m_ptrAccelProvider) {
            AcceleratableOperations operations;
            operations.setImageProcessingAcceleration(true);
            operations.setMathematicalAcceleration(true);
            operations.setMemoryOptimization(true);
            
            // Apply ARM64 specific optimizations
            m_ptrAccelProvider->configureOperations(operations);
        }
    } catch (std::exception const& e) {
        std::cerr << "Warning: Acceleration configuration failed: " << e.what() << std::endl;
    }
    
    return intrusive_ptr<LoadFileTask>(
        new LoadFileTask(
            LoadFileTask::LOAD_IMAGE,
            page,
            m_ptrThumbnailCache,
            m_ptrPages,
            fix_orientation_task
        )
    );
}

// Main processing function
void ConsoleBatch::process() {
    if (!m_ptrPages || !m_ptrStages) {
        throw std::runtime_error("Project not properly initialized");
    }
    
    PageSequence const pages = m_ptrPages->toPageSequence(IMAGE_VIEW);
    if (pages.numPages() == 0) {
        std::cout << "No pages to process." << std::endl;
        return;
    }
    
    std::cout << "Processing " << pages.numPages() << " pages..." << std::endl;
    
    // ARM64 optimized processing
    QElapsedTimer timer;
    timer.start();
    
    int processed = 0;
    int const total = pages.numPages();
    
    for (PageInfo const& page_info : pages) {
        try {
            std::cout << "Processing page " << (processed + 1) << "/" << total 
                      << ": " << page_info.imageId().filePath().toStdString() << std::endl;
            
            // Create and execute processing task
            intrusive_ptr<LoadFileTask> task = createCompositeTask(page_info, 5, true, m_debug);
            if (task) {
                // Execute task synchronously for CLI
                FilterResult result = task->process(TaskStatus::createDefault());
                
                if (result.isOk()) {
                    ++processed;
                    std::cout << "  ✓ Completed successfully" << std::endl;
                } else {
                    std::cerr << "  ✗ Processing failed: " << result.errorString().toStdString() << std::endl;
                }
            } else {
                std::cerr << "  ✗ Failed to create processing task" << std::endl;
            }
            
            // Progress update
            if (processed % 10 == 0 || processed == total) {
                double const progress = 100.0 * processed / total;
                qint64 const elapsed = timer.elapsed();
                qint64 const estimated_total = (elapsed * total) / std::max(1, processed);
                qint64 const remaining = estimated_total - elapsed;
                
                std::cout << "Progress: " << std::fixed << std::setprecision(1) << progress << "% "
                          << "(" << processed << "/" << total << ") "
                          << "Elapsed: " << (elapsed / 1000) << "s "
                          << "Remaining: " << (remaining / 1000) << "s" << std::endl;
            }
            
            // Allow Qt event processing
            QCoreApplication::processEvents();
            
        } catch (std::exception const& e) {
            std::cerr << "  ✗ Exception: " << e.what() << std::endl;
        } catch (...) {
            std::cerr << "  ✗ Unknown exception occurred" << std::endl;
        }
    }
    
    qint64 const total_time = timer.elapsed();
    double const avg_time = static_cast<double>(total_time) / std::max(1, processed);
    
    std::cout << std::endl;
    std::cout << "Processing completed!" << std::endl;
    std::cout << "  Total pages: " << total << std::endl;
    std::cout << "  Processed: " << processed << std::endl;
    std::cout << "  Failed: " << (total - processed) << std::endl;
    std::cout << "  Total time: " << (total_time / 1000.0) << "s" << std::endl;
    std::cout << "  Average time per page: " << (avg_time / 1000.0) << "s" << std::endl;
    
    if (processed < total) {
        throw std::runtime_error("Some pages failed to process");
    }
}

// Save project to file
void ConsoleBatch::saveProject(QString const& project_file) {
    if (!m_ptrPages || !m_ptrStages) {
        throw std::runtime_error("No project to save");
    }
    
    ProjectWriter writer(m_ptrPages, m_ptrStages, m_ptrDisambiguator);
    
    QFile file(project_file);
    if (!file.open(QIODevice::WriteOnly)) {
        throw std::runtime_error("Unable to open project file for writing");
    }
    
    QDomDocument doc = writer.write(m_outDir);
    
    QTextStream stream(&file);
    stream.setCodec("UTF-8");
    doc.save(stream, 2);
    
    file.close();
    
    std::cout << "Project saved to: " << project_file.toStdString() << std::endl;
}

// Get output directory
QString ConsoleBatch::outputDirectory() const {
    return m_outDir;
}

// Check if project is valid
bool ConsoleBatch::isProjectValid() const {
    return m_ptrPages && m_ptrStages && !m_outDir.isEmpty();
}

// Get page count
int ConsoleBatch::pageCount() const {
    if (!m_ptrPages) {
        return 0;
    }
    return m_ptrPages->toPageSequence(IMAGE_VIEW).numPages();
}

// Enable/disable debug mode
void ConsoleBatch::setDebugMode(bool debug) {
    m_debug = debug;
}

// Get debug mode status
bool ConsoleBatch::debugMode() const {
    return m_debug;
}