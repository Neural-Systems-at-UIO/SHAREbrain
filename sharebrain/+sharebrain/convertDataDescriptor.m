function convertDataDescriptor(sourceFile, markdownFile, options)
%convertDataDescriptor - Convert the data descriptor of an EBRAINS dataset to Markdown
%   sharebrain.convertDataDescriptor(sourceFile, markdownFile) writes the
%   text of the data descriptor sourceFile to the Markdown file
%   markdownFile. sourceFile is a PDF, plain text or Markdown file:
%
%     PDF        - The text is extracted with pdftotext of poppler, which
%                  must be installed. Lines that are on at least half of
%                  the pages (page headers and footers) and lines that hold
%                  only a number (page numbers) are removed. A PDF without
%                  text, such as a scanned one, gives the error
%                  SHAREbrain:ConvertDataDescriptor:NoText.
%     Plain text - The file is read as UTF-8, or as Windows-1252 when it is
%                  not valid UTF-8, as older HBP descriptors are.
%     Markdown   - The file is copied as it is.
%
%   In a PDF or plain text descriptor, a line becomes a level 2 heading
%   when its letters are all capitals, as the section titles of the EBRAINS
%   and HBP templates are ("METHODS*"), or when it has at most eight words
%   and ends with a colon ("COMPUTATIONAL METHODS - Data acquisition:"),
%   unless it has a parenthesis that it does not close. Tables and figures
%   are not kept: pdftotext gives the cells of a table as lines of text.
%
%   The Markdown starts with a title and a line that names the source file.
%
%   convertDataDescriptor(..., Title=TEXT) sets the title. The default is
%   "Data descriptor".
%
%   convertDataDescriptor(..., PdfToTextCommand=COMMAND) runs COMMAND
%   instead of "pdftotext", for example the full path of pdftotext when its
%   folder is not on the PATH that MATLAB has.
%
%   See also sharebrain.writeDatasetDocs

    arguments
        sourceFile (1,1) string {mustBeFile}
        markdownFile (1,1) string
        options.Title (1,1) string = "Data descriptor"
        options.PdfToTextCommand (1,1) string = "pdftotext"
    end

    [~, sourceName, extension] = fileparts(sourceFile);
    sourceFileName = sourceName + extension;

    switch lower(extension)
        case ".pdf"
            lines = markHeadings(readPdfLines(sourceFile, options.PdfToTextCommand));
            origin = "Converted from `" + sourceFileName + "` with pdftotext. " + ...
                "The layout, tables and figures of the PDF are not kept.";
        case ".txt"
            lines = markHeadings(splitlines(readText(sourceFile)));
            origin = "Converted from `" + sourceFileName + "`.";
        case ".md"
            lines = splitlines(readText(sourceFile));
            origin = "Copied from `" + sourceFileName + "`.";
        otherwise
            error("SHAREbrain:ConvertDataDescriptor:UnsupportedFormat", ...
                "The data descriptor '%s' is a %s file. Give a PDF, plain text (.txt) " + ...
                "or Markdown (.md) file.", sourceFileName, extension)
    end

    lines = ["# " + options.Title; ""; origin; ""; lines];
    writelines(collapseBlankLines(lines), markdownFile)
end

function lines = readPdfLines(pdfFile, pdfToTextCommand)
%readPdfLines - The lines of text of a PDF, without page headers, footers and numbers

    textFile = tempname + ".txt";
    cleanup = onCleanup(@() deleteIfFile(textFile));

    command = sprintf('%s -enc UTF-8 "%s" "%s"', pdfToTextCommand, pdfFile, textFile);
    [status, message] = system(command);
    if status ~= 0
        error("SHAREbrain:ConvertDataDescriptor:PdfToTextFailed", ...
            "pdftotext could not extract the text of '%s': %s\nInstall poppler, " + ...
            "which provides pdftotext, or give its full path as PdfToTextCommand.", ...
            pdfFile, strtrim(message))
    end

    % pdftotext ends every page with a form feed
    pages = split(string(readText(textFile)), char(12));
    pages(strlength(strtrim(pages)) == 0) = [];
    if isempty(pages)
        error("SHAREbrain:ConvertDataDescriptor:NoText", ...
            "The PDF '%s' has no text that pdftotext can extract, as a scanned PDF has none. " + ...
            "Give a PDF with a text layer, for example one made with OCR, or a plain text version.", pdfFile)
    end
    pageLines = arrayfun(@(page) strtrim(splitlines(page)), pages, 'UniformOutput', false);

    repeatedLines = strings(0, 1);
    numPages = numel(pages);
    if numPages > 1
        linesPerPage = cellfun(@(pageText) unique(pageText(strlength(pageText) > 0)), ...
            pageLines, 'UniformOutput', false);
        [uniqueLines, ~, lineIndex] = unique(vertcat(linesPerPage{:}));
        numPagesWithLine = accumarray(lineIndex, 1);
        repeatedLines = uniqueLines(numPagesWithLine >= max(2, numPages / 2));
    end

    lines = vertcat(pageLines{:});
    isPageNumber = matches(lines, digitsPattern(1, 3));
    lines(ismember(lines, repeatedLines) | isPageNumber) = [];
end

function text = readText(filePath)
%readText - The text of a file that is UTF-8, or else Windows-1252

    fileID = fopen(filePath, 'r');
    bytes = fread(fileID, Inf, '*uint8')';
    fclose(fileID);

    text = native2unicode(bytes, 'UTF-8');
    if ~isequal(unicode2native(text, 'UTF-8'), bytes)
        text = native2unicode(bytes, 'windows-1252');
    end

    byteOrderMark = char(65279);
    if startsWith(text, byteOrderMark)
        text = text(2:end);
    end
    text = string(text);
end

function lines = markHeadings(lines)
%markHeadings - Make the section titles of a descriptor level 2 headings

    lines = strtrim(string(lines));
    letters = regexprep(lines, '[^A-Za-z]', '');
    isCapitalLine = strlength(letters) >= 4 & strlength(lines) <= 80 & lines == upper(lines);

    numWords = cellfun(@(line) numel(split(line)), cellstr(lines));
    isLabelLine = endsWith(lines, ":") & strlength(lines) <= 60 & numWords(:) <= 8 ...
        & startsWith(lines, characterListPattern("A", "Z"));

    % A line with an unclosed parenthesis is part of a sentence or table
    % cell that pdftotext split, such as "NWB 2.0 (HDF5"
    isFragment = count(lines, "(") ~= count(lines, ")");

    isHeading = (isCapitalLine | isLabelLine) & ~isFragment;
    headings = "## " + regexprep(lines(isHeading), '[\s*:]+$', '');

    % A heading needs blank lines around it to be one in Markdown
    lines(isHeading) = newline + headings + newline;
    lines = splitlines(strjoin(lines, newline));
end

function lines = collapseBlankLines(lines)
%collapseBlankLines - Keep at most one blank line between paragraphs
    lines = strip(lines, 'right');
    isBlank = strlength(lines) == 0;
    lines(isBlank & [false; isBlank(1:end-1)]) = [];
end

function deleteIfFile(filePath)
    if isfile(filePath)
        delete(filePath)
    end
end
