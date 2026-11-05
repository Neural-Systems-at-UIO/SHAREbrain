classdef ConvertDataDescriptorTest < matlab.unittest.TestCase
%ConvertDataDescriptorTest - Tests for sharebrain.convertDataDescriptor
%
%   Each test writes a small descriptor in one of the formats found in
%   EBRAINS datasets and checks the Markdown that is written for it. The
%   PDF test makes a two-page PDF with exportgraphics and needs pdftotext.
%
%   Run tests:
%       runtests('ConvertDataDescriptorTest')

    properties
        Folder string
    end

    methods (TestMethodSetup)
        function createFolder(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            testCase.Folder = string(testCase.applyFixture(TemporaryFolderFixture).Folder);
        end
    end

    methods (Test)
        function testWindows1252TextIsDecoded(testCase)
            % Older HBP descriptors are Windows-1252, where 0xB5 is µ
            sourceFile = fullfile(testCase.Folder, "descriptor.txt");
            fileID = fopen(sourceFile, "w");
            fwrite(fileID, [uint8('Slices were 230 '), uint8(181), uint8('m thick.')]);
            fclose(fileID);

            lines = testCase.convert(sourceFile);

            testCase.verifyTrue(any(lines == "Slices were 230 " + char(181) + "m thick."))
        end

        function testCapitalAndLabelLinesBecomeHeadings(testCase)
            sourceFile = fullfile(testCase.Folder, "descriptor.txt");
            writelines(["TITLE*"; "Recordings of granule cells"; ""; ...
                "COMPUTATIONAL METHODS - Data acquisition:"; "Recorded with Clampex."; ...
                "NWB 2.0 (HDF5"; "Reference atlas used: Paxinos & Watson."], sourceFile)

            lines = testCase.convert(sourceFile);

            testCase.verifyEqual(lines(startsWith(lines, "## ")), ...
                ["## TITLE"; "## COMPUTATIONAL METHODS - Data acquisition"])
        end

        function testMarkdownIsCopied(testCase)
            sourceFile = fullfile(testCase.Folder, "descriptor.md");
            content = ["# Morphology of interneurons"; ""; "- Cells were filled with biocytin."];
            writelines(content, sourceFile)

            lines = testCase.convert(sourceFile);

            testCase.verifyEqual(lines(end-2:end), content)
        end

        function testTitleAndSourceAreNamed(testCase)
            sourceFile = fullfile(testCase.Folder, "descriptor.txt");
            writelines("Some text.", sourceFile)

            lines = testCase.convert(sourceFile, "Data descriptor of garad_2022");

            testCase.verifyEqual(lines(1), "# Data descriptor of garad_2022")
            testCase.verifyTrue(contains(lines(3), "descriptor.txt"))
        end

        function testPdfPageHeadersAndNumbersAreRemoved(testCase)
            [status, ~] = system('pdftotext -v');
            testCase.assumeEqual(status, 0, 'pdftotext is not installed.')
            sourceFile = fullfile(testCase.Folder, "descriptor.pdf");
            pageHeader = "Title: Test dataset | version: v1.0";
            testCase.writePdfPage(sourceFile, [pageHeader, "SUMMARY", "First page text.", "1"], false)
            testCase.writePdfPage(sourceFile, [pageHeader, "METHODS", "Second page text.", "2"], true)

            lines = testCase.convert(sourceFile);

            testCase.verifyFalse(any(contains(lines, pageHeader)))
            testCase.verifyFalse(any(ismember(lines, ["1", "2"])))
            testCase.verifyEqual(lines(startsWith(lines, "## ")), ["## SUMMARY"; "## METHODS"])
            testCase.verifyTrue(any(lines == "Second page text."))
        end

        function testPdfWithoutTextErrors(testCase)
            % A PDF exported as an image has no text layer, like a scan
            [status, ~] = system('pdftotext -v');
            testCase.assumeEqual(status, 0, 'pdftotext is not installed.')
            sourceFile = fullfile(testCase.Folder, "scanned-descriptor.pdf");
            testCase.writePdfPage(sourceFile, ["SUMMARY", "Text that is only pixels."], false, 'image')

            testCase.verifyError(@() testCase.convert(sourceFile), ...
                'SHAREbrain:ConvertDataDescriptor:NoText')
        end

        function testUnsupportedFormatErrors(testCase)
            sourceFile = fullfile(testCase.Folder, "descriptor.docx");
            writelines("Not a supported format.", sourceFile)

            testCase.verifyError(@() testCase.convert(sourceFile), ...
                'SHAREbrain:ConvertDataDescriptor:UnsupportedFormat')
        end
    end

    methods (Access = private)
        function lines = convert(testCase, sourceFile, title)
            if nargin < 3
                title = "Data descriptor";
            end
            markdownFile = fullfile(testCase.Folder, "descriptor-converted.md");
            sharebrain.convertDataDescriptor(sourceFile, markdownFile, Title=title)
            lines = readlines(markdownFile);
            lines(end) = []; % writelines ends the file with a newline
        end

        function writePdfPage(~, pdfFile, textLines, isAppended, contentType)
            % One line of text per text object, from the top of the page
            % down. contentType 'image' writes the page as pixels only.
            if nargin < 5
                contentType = 'vector';
            end
            figureHandle = figure('Visible', 'off');
            closeFigure = onCleanup(@() close(figureHandle));
            axesHandle = axes(figureHandle, 'Visible', 'off', 'Position', [0 0 1 1]);
            yPositions = linspace(0.9, 0.1, numel(textLines));
            for i = 1:numel(textLines)
                text(axesHandle, 0.05, yPositions(i), textLines(i), 'Interpreter', 'none')
            end
            exportgraphics(figureHandle, pdfFile, 'ContentType', contentType, 'Append', isAppended)
        end
    end
end
