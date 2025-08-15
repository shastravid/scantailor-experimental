/*
    Scan Tailor - Interactive post-processing tool for scanned pages.

    ConsoleBatch - Batch processing scanned pages from command line.
    Copyright (C) 2011 Petr Kovar <pejuko@gmail.com>

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

#include <vector>
#include <iostream>
#include <assert.h>
#include <memory>

// Qt6 includes for Ubuntu ARM64
#include <QCoreApplication>
#include <QFile>
#include <QString>
#include <QIODevice>
#include <QDomDocument>
#include <QMap>

#include "Utils.h"
#include "IntrusivePtr.h"
#include "NonCopyable.h"
#include "ProjectPages.h"
#include "PageSelectionAccessor.h"
#include "StageSequence.h"
#include "ProcessingTaskQueue.h"
#include "FileNameDisambiguator.h"
#include "OutputFileNameGenerator.h"
#include "ImageInfo.h"
#include "ImageFileInfo.h"
#include "PageInfo.h"
#include "PageSequence.h"
#include "ImageId.h"
#include "ThumbnailPixmapCache.h"
#include "LoadFileTask.h"
#include "ProjectWriter.h"
#include "ProjectReader.h"
#include "OrthogonalRotation.h"
#include "SelectedPage.h"
#include "acceleration/DefaultAccelerationProvider.h"

#include "stages/fix_orientation/Settings.h"
#include "stages/fix_orientation/Filter.h"
#include "stages/fix_orientation/Task.h"
#include "stages/fix_orientation/CacheDrivenTask.h"
#include "stages/page_split/Settings.h"
#include "stages/page_split/Filter.h"
#include "stages/page_split/Task.h"
#include "stages/page_split/CacheDrivenTask.h"
#include "stages/deskew/Settings.h"
#include "stages/deskew/Filter.h"
#include "stages/deskew/Task.h"
#include "stages/deskew/CacheDrivenTask.h"
#include "stages/select_content/Settings.h"
#include "stages/select_content/Filter.h"
#include "stages/select_content/Task.h"
#include "stages/select_content/CacheDrivenTask.h"
#include "stages/page_layout/Settings.h"
#include "stages/page_layout/Filter.h"
#include "stages/page_layout/Task.h"
#include "stages/page_layout/CacheDrivenTask.h"
#include "stages/output/Settings.h"
#include "stages/output/Params.h"
#include "stages/output/Filter.h"
#include "stages/output/Task.h"
#include "stages/output/CacheDrivenTask.h"

#include "ConsoleBatch.h"
#include "CommandLine.h"

// Ubuntu ARM64 optimized constructor
ConsoleBatch::ConsoleBatch(std::vector<ImageFileInfo> const& images, QString const& output_directory, Qt::LayoutDirection const layout)
    :   batch(true), debug(true),
        m_pAccelerationProvider(nullptr),
        m_ptrDisambiguator(new FileNameDisambiguator()),
        m_ptrPages(new ProjectPages(images, ProjectPages::AUTO_PAGES, layout))
{
    // Safe acceleration provider initialization for ARM64 without GPU
    try {
        if (QCoreApplication::instance()) {
            m_pAccelerationProvider = new DefaultAccelerationProvider(QCoreApplication::instance());
        }
    } catch (const std::exception& e) {
        std::cerr << "Warning: Failed to initialize acceleration provider (" << e.what() << "), continuing without acceleration." << std::endl;
        m_pAccelerationProvider = nullptr;
    } catch (...) {
        std::cerr << "Warning: Failed to initialize acceleration provider, continuing without acceleration." << std::endl;
        m_pAccelerationProvider = nullptr;
    }
    
    PageSelectionAccessor const accessor((IntrusivePtr<PageSelectionProvider>())); // Won't really be used anyway.
    m_ptrStages = IntrusivePtr<StageSequence>(new StageSequence(m_ptrPages, accessor));

    // Create thumbnail cache without acceleration for ARM64
    m_ptrThumbnailCache = Utils::createThumbnailCache(output_directory);
    m_outFileNameGen = OutputFileNameGenerator(m_ptrDisambiguator, output_directory, m_ptrPages->layoutDirection());
}

// Ubuntu ARM64 optimized project file constructor
ConsoleBatch::ConsoleBatch(QString const project_file)
    :   batch(true), debug(true),
        m_pAccelerationProvider(nullptr)
{
    // Safe acceleration provider initialization for ARM64 without GPU
    try {
        if (QCoreApplication::instance()) {
            m_pAccelerationProvider = new DefaultAccelerationProvider(QCoreApplication::instance());
        }
    } catch (const std::exception& e) {
        std::cerr << "Warning: Failed to initialize acceleration provider (" << e.what() << "), continuing without acceleration." << std::endl;
        m_pAccelerationProvider = nullptr;
    } catch (...) {
        std::cerr << "Warning: Failed to initialize acceleration provider, continuing without acceleration." << std::endl;
        m_pAccelerationProvider = nullptr;
    }
    
    QFile file(project_file);
    if (!file.open(QIODevice::ReadOnly))
    {
        throw std::runtime_error("Unable to open the project file.");
    }

    QDomDocument doc;
    if (!doc.setContent(&file))
    {
        throw std::runtime_error("The project file is broken.");
    }

    file.close();

    ProjectReader reader(doc);
    reader.readImageFileInfo();
    reader.readSelectedPage();

    PageSelectionAccessor const accessor(reader.pageSelectionProvider());
    m_ptrPages = reader.pages();
    m_ptrStages = IntrusivePtr<StageSequence>(new StageSequence(m_ptrPages, accessor));
    m_ptrStages->performRelinking(reader.createRelinker());

    QString const output_directory(reader.outputDirectory());
    if (output_directory.isEmpty())
    {
        throw std::runtime_error("Output directory is not set.");
    }

    // Create thumbnail cache without acceleration for ARM64
    m_ptrThumbnailCache = Utils::createThumbnailCache(output_directory);
    m_ptrDisambiguator = reader.namingDisambiguator();
    m_outFileNameGen = OutputFileNameGenerator(m_ptrDisambiguator, output_directory, m_ptrPages->layoutDirection());
}

// ARM64 optimized task creation without GPU acceleration
BackgroundTaskPtr
ConsoleBatch::createCompositeTask(
    PageInfo const& page,
    int const last_filter_idx)
{
    IntrusivePtr<fix_orientation::Task> fix_orientation_task;
    IntrusivePtr<page_split::Task> page_split_task;
    IntrusivePtr<deskew::Task> deskew_task;
    IntrusivePtr<select_content::Task> select_content_task;
    IntrusivePtr<page_layout::Task> page_layout_task;
    IntrusivePtr<output::Task> output_task;

    if (batch)
    {
        debug = false;
    }
    if (last_filter_idx >= m_ptrStages->outputFilterIdx())
    {
        output_task = m_ptrStages->outputFilter()->createTask(
                          page.id(), m_ptrThumbnailCache, m_outFileNameGen, batch, debug
                      );
        debug = false;
    }
    if (last_filter_idx >= m_ptrStages->pageLayoutFilterIdx())
    {
        page_layout_task = m_ptrStages->pageLayoutFilter()->createTask(
                               page.id(), output_task, batch, debug
                           );
        debug = false;
    }
    if (last_filter_idx >= m_ptrStages->selectContentFilterIdx())
    {
        select_content_task = m_ptrStages->selectContentFilter()->createTask(
                                  page.id(), page_layout_task, batch, debug
                              );
        debug = false;
    }
    if (last_filter_idx >= m_ptrStages->deskewFilterIdx())
    {
        deskew_task = m_ptrStages->deskewFilter()->createTask(
                          page.id(), select_content_task, batch, debug
                      );
        debug = false;
    }
    if (last_filter_idx >= m_ptrStages->pageSplitFilterIdx())
    {
        page_split_task = m_ptrStages->pageSplitFilter()->createTask(
                              page, deskew_task, batch, debug
                          );
        debug = false;
    }
    if (last_filter_idx >= m_ptrStages->fixOrientationFilterIdx())
    {
        fix_orientation_task = m_ptrStages->fixOrientationFilter()->createTask(
                                   page.id(), page_split_task, batch
                               );
        debug = false;
    }
    assert(fix_orientation_task);

    // ARM64 optimized acceleration handling - no GPU operations
    std::shared_ptr<AcceleratableOperations> accel_ops;
    // For ARM64 CLI without GPU, we don't use acceleration
    // This prevents any GPU-related crashes on Oracle Cloud VPS
    
    return BackgroundTaskPtr(
               new LoadFileTask(
                   BackgroundTask::BATCH, page,
                   accel_ops,  // nullptr for ARM64 CLI
                   m_ptrThumbnailCache, m_ptrPages, fix_orientation_task
               )
           );
}

void
ConsoleBatch::process()
{
    PageSequence const page_sequence(m_ptrPages->toPageSequence(PAGE_VIEW));
    size_t const num_pages = page_sequence.numPages();

    for (size_t i = 0; i < num_pages; ++i)
    {
        PageInfo const& page_info = page_sequence.pageAt(i);
        if (CommandLine::get().isVerbose())
        {
            std::cout << "\rProcessing: " << (i + 1) << "/" << num_pages << " " << page_info.imageId().filePath().toLocal8Bit().constData();
            std::cout.flush();
        }

        BackgroundTaskPtr bgTask = createCompositeTask(page_info, m_ptrStages->lastFilterIdx());
        (*bgTask)();
    }

    if (CommandLine::get().isVerbose())
    {
        std::cout << std::endl;
    }
}

void
ConsoleBatch::saveProject(QString const project_file)
{
    PageSelectionAccessor const accessor((IntrusivePtr<PageSelectionProvider>()));
    ProjectWriter writer(m_ptrPages, accessor, m_ptrStages->filters());
    writer.write(project_file, m_ptrDisambiguator);
}

// Filter setup methods remain unchanged
void
ConsoleBatch::setupFilter(int idx, std::set<PageId> allPages)
{
    if (idx == m_ptrStages->fixOrientationFilterIdx())
        setupFixOrientation(allPages);
    else if (idx == m_ptrStages->pageSplitFilterIdx())
        setupPageSplit(allPages);
    else if (idx == m_ptrStages->deskewFilterIdx())
        setupDeskew(allPages);
    else if (idx == m_ptrStages->selectContentFilterIdx())
        setupSelectContent(allPages);
    else if (idx == m_ptrStages->pageLayoutFilterIdx())
        setupPageLayout(allPages);
    else if (idx == m_ptrStages->outputFilterIdx())
        setupOutput(allPages);
}

void
ConsoleBatch::setupFixOrientation(std::set<PageId> allPages)
{
    IntrusivePtr<fix_orientation::Filter> fix_orientation = m_ptrStages->fixOrientationFilter();
    CommandLine const& cli = CommandLine::get();

    for (std::set<PageId>::iterator i = allPages.begin(); i != allPages.end(); ++i)
    {
        PageId const& page_id = *i;
        OrthogonalRotation rotation;

        if (cli.hasOrientation())
        {
            switch (cli.getOrientation())
            {
            case CommandLine::LEFT:
                rotation.prevClockwiseDirection();
                break;
            case CommandLine::RIGHT:
                rotation.nextClockwiseDirection();
                break;
            case CommandLine::UPSIDEDOWN:
                rotation.nextClockwiseDirection();
                rotation.nextClockwiseDirection();
                break;
            default:
                break;
            }
        }

        fix_orientation->getSettings()->applyRotation(page_id.imageId(), rotation);
    }
}

void
ConsoleBatch::setupPageSplit(std::set<PageId> allPages)
{
    IntrusivePtr<page_split::Filter> page_split = m_ptrStages->pageSplitFilter();
    CommandLine const& cli = CommandLine::get();

    if (cli.hasLayout())
    {
        page_split->getSettings()->setLayoutTypeForAllPages(cli.getLayout());
    }
}

void
ConsoleBatch::setupDeskew(std::set<PageId> allPages)
{
    IntrusivePtr<deskew::Filter> deskew = m_ptrStages->deskewFilter();
    CommandLine const& cli = CommandLine::get();

    for (std::set<PageId>::iterator i = allPages.begin(); i != allPages.end(); ++i)
    {
        PageId const& page_id = *i;
        OrthogonalRotation rotation;
        deskew::Dependencies const deps(QPolygonF(), rotation);

        if (cli.hasDeskewAngle())
        {
            double const angle = cli.getDeskewAngle();
            deskew->getSettings()->setPageAngle(page_id, angle);
        }
        else
        {
            deskew::Settings::ApplyToResult const result = deskew->getSettings()->applyToPageId(
                        page_id, deps, deskew::MODE_AUTO
                    );
            if (result == deskew::Settings::MATCH_FOUND)
            {
                // This page already has settings, so we don't touch it.
                continue;
            }
        }
    }
}

void
ConsoleBatch::setupSelectContent(std::set<PageId> allPages)
{
    IntrusivePtr<select_content::Filter> select_content = m_ptrStages->selectContentFilter();
    CommandLine const& cli = CommandLine::get();

    for (std::set<PageId>::iterator i = allPages.begin(); i != allPages.end(); ++i)
    {
        PageId const& page_id = *i;

        if (cli.hasContentRect())
        {
            QRectF const content_rect = cli.getContentRect();
            QSizeF const content_size_mm = cli.getContentSizeMM();
            select_content->getSettings()->setPageDetectionMode(
                page_id, select_content::MODE_MANUAL
            );
            select_content->getSettings()->setPageDetectionBox(page_id, content_rect);
            if (!content_size_mm.isNull())
            {
                select_content->getSettings()->setPageDetectionTargetSize(page_id, content_size_mm);
            }
        }
    }
}

void
ConsoleBatch::setupPageLayout(std::set<PageId> allPages)
{
    IntrusivePtr<page_layout::Filter> page_layout = m_ptrStages->pageLayoutFilter();
    CommandLine const& cli = CommandLine::get();

    for (std::set<PageId>::iterator i = allPages.begin(); i != allPages.end(); ++i)
    {
        PageId const& page_id = *i;

        if (cli.hasMargins())
        {
            page_layout::Margins const margins = cli.getMargins();
            page_layout->getSettings()->setHardMarginsMM(page_id, margins);
        }
    }
}

void
ConsoleBatch::setupOutput(std::set<PageId> allPages)
{
    IntrusivePtr<output::Filter> output = m_ptrStages->outputFilter();
    CommandLine const& cli = CommandLine::get();

    for (std::set<PageId>::iterator i = allPages.begin(); i != allPages.end(); ++i)
    {
        PageId const& page_id = *i;
        output::Params params(output->getSettings()->getParams(page_id));

        if (cli.hasOutputDpi())
        {
            Dpi const dpi = cli.getOutputDpi();
            params.setOutputDpi(dpi);
        }

        if (cli.hasColorMode())
        {
            output::ColorParams::ColorMode const color_mode = cli.getColorMode();
            output::ColorParams color_params = params.colorParams();
            color_params.setColorMode(color_mode);
            params.setColorParams(color_params);

            if (color_mode == output::ColorParams::MIXED)
            {
                output::SplittingOptions splitting_options = params.splittingOptions();
                if (cli.hasPictureShape())
                {
                    splitting_options.setSplitOutput(true);
                    splitting_options.setPictureShape(cli.getPictureShape());
                }
                if (cli.hasSplittingOptions())
                {
                    cli.getSplittingOptions(splitting_options);
                }
                params.setSplittingOptions(splitting_options);
            }
        }

        if (cli.hasWhiteMargins())
        {
            params.setWhiteMargins(cli.getWhiteMargins());
        }

        if (cli.hasNormalizeIllumination())
        {
            params.setNormalizeIllumination(cli.getNormalizeIllumination());
        }

        if (cli.hasThreshold())
        {
            output::BinarizationOptions binarization_options = params.binarizationOptions();
            binarization_options.setThresholdAdjustment(cli.getThreshold());
            params.setBinarizationOptions(binarization_options);
        }

        if (cli.hasDespeckleLevel())
        {
            output::DespeckleLevel const despeckle_level = cli.getDespeckleLevel();
            params.setDespeckleLevel(despeckle_level);
        }

        if (cli.hasDepthPerception())
        {
            output::DepthPerception const depth_perception = cli.getDepthPerception();
            output::DewarpingOptions dewarping_options = params.dewarpingOptions();
            dewarping_options.setDepthPerception(depth_perception);
            params.setDewarpingOptions(dewarping_options);
        }

        if (cli.hasDewarpingOptions())
        {
            output::DewarpingOptions dewarping_options = params.dewarpingOptions();
            cli.getDewarpingOptions(dewarping_options);
            params.setDewarpingOptions(dewarping_options);
        }

        output->getSettings()->setParams(page_id, params);
    }
}