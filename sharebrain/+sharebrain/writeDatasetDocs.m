function docFiles = writeDatasetDocs(datasetVersionUUID, cloneFolder, options)
%writeDatasetDocs - Write the documentation of an EBRAINS dataset into its NANSEN project
%   docFiles = sharebrain.writeDatasetDocs(datasetVersionUUID, cloneFolder)
%   writes text files about the EBRAINS dataset version datasetVersionUUID,
%   cloned into cloneFolder, into the folder docs of the current NANSEN
%   project, and describes them in the project's README.md:
%
%     docs/data-descriptor.md       - The data descriptor of the dataset,
%                                     converted with convertDataDescriptor.
%                                     The descriptor is the PDF, Markdown or
%                                     plain text file in cloneFolder whose
%                                     name contains "descriptor". An empty
%                                     placeholder is downloaded first. A PDF
%                                     without text gives a warning and no
%                                     Markdown file.
%     docs/kg-dataset-version.jsonld - openMINDS metadata of the dataset
%                                     version from the EBRAINS Knowledge
%                                     Graph, with two levels of linked
%                                     instances (kgpull).
%
%   The section "Dataset" of README.md lists these files, the clone and
%   its bucket, the session and subject tables and their CSV copies, the
%   data variables with their file adapters and descriptions, and the
%   MATLAB code that loads a variable of a session. The section is replaced
%   each time this function runs; the rest of README.md is kept.
%
%   The project also gets AGENTS.md, the instructions for working with a
%   project made this way, copied from
%   sharebrain/resources/project-agents-template.md.
%
%   docFiles lists the files that were written.
%
%   writeDatasetDocs(..., Name=Value) also specifies:
%       Project           - NANSEN project to write into. Default is the
%                           current project, which the variable table
%                           needs, because file adapters are listed from
%                           the current project.
%       DsmConfigFile     - Dataset Structure Model config that the data
%                           locations were imported from, named in
%                           README.md.
%       IncludeKGMetadata - Whether to download the Knowledge Graph
%                           metadata, which needs an EBRAINS login.
%                           Default is true.
%
%   See also sharebrain.convertDataDescriptor, kgpull, openminds.Collection

    arguments
        datasetVersionUUID (1,1) string {omkg.validator.mustBeValidKGIdentifier}
        cloneFolder (1,1) string {mustBeFolder}
        options.Project = nansen.getCurrentProject()
        options.DsmConfigFile (1,1) string = ""
        options.IncludeKGMetadata (1,1) logical = true
    end

    project = options.Project;
    docsFolder = fullfile(project.FolderPath, "docs");
    if ~isfolder(docsFolder)
        mkdir(docsFolder)
    end
    docFiles = strings(1, 0);

    datasetName = "";
    if options.IncludeKGMetadata
        jsonldFile = fullfile(docsFolder, "kg-dataset-version.jsonld");
        datasetVersion = kgpull(datasetVersionUUID, NumLinksToResolve=2);
        openminds.Collection(datasetVersion).save(jsonldFile);
        datasetName = string(datasetVersion.fullName);
        docFiles(end+1) = jsonldFile;
    end

    descriptorFile = findDataDescriptor(cloneFolder);
    if strlength(descriptorFile) > 0
        markdownFile = fullfile(docsFolder, "data-descriptor.md");
        try
            sharebrain.convertDataDescriptor(descriptorFile, markdownFile, ...
                Title="Data descriptor of " + project.Name);
            docFiles(end+1) = markdownFile;
        catch exception
            % A scanned descriptor should not stop the other documents
            if exception.identifier ~= "SHAREbrain:ConvertDataDescriptor:NoText"
                rethrow(exception)
            end
            warning("SHAREbrain:WriteDatasetDocs:DescriptorWithoutText", ...
                "%s The descriptor is not converted.", exception.message)
        end
    end

    section = buildReadmeSection(project, datasetVersionUUID, datasetName, cloneFolder, ...
        descriptorFile, docFiles, options.DsmConfigFile);
    readmeFile = fullfile(project.FolderPath, "README.md");
    writeReadmeSection(readmeFile, section)
    docFiles(end+1) = readmeFile;

    sharebrainFolder = fileparts(fileparts(mfilename('fullpath')));
    agentsFile = fullfile(project.FolderPath, "AGENTS.md");
    copyfile(fullfile(sharebrainFolder, "resources", "project-agents-template.md"), agentsFile)
    docFiles(end+1) = agentsFile;
end

function descriptorFile = findDataDescriptor(cloneFolder)
%findDataDescriptor - The data descriptor of a cloned dataset, downloaded if it is a placeholder
%   Returns "" when the clone has no file whose name contains "descriptor".

    descriptorFile = "";
    candidates = dir(fullfile(cloneFolder, "**", "*"));
    candidates = candidates(~[candidates.isdir]);
    [~, ~, extensions] = fileparts(string({candidates.name}));
    isDescriptor = contains(string({candidates.name}), "descriptor", "IgnoreCase", true) ...
        & ismember(lower(extensions), [".pdf", ".md", ".txt"]);
    candidates = candidates(isDescriptor);
    if isempty(candidates)
        return
    end

    % A file that is already local comes first, so that nothing is
    % downloaded when a descriptor is at hand. Then a PDF, the descriptor as
    % published, before Markdown and text files, which are often exports.
    [~, ~, extensions] = fileparts(string({candidates.name}));
    formatRank = arrayfun(@(ext) find([".pdf", ".md", ".txt"] == lower(ext)), extensions);
    isPlaceholder = [candidates.bytes] == 0;
    [~, order] = sortrows([isPlaceholder(:), formatRank(:)]);
    candidate = candidates(order(1));
    descriptorFile = string(fullfile(candidate.folder, candidate.name));

    source = nansen.module.sharebrain.dataio.EbrainsBucketSource(cloneFolder);
    if source.isOnlineOnly(descriptorFile)
        source.download(descriptorFile)
    end

    if dir(descriptorFile).bytes == 0
        warning("SHAREbrain:WriteDatasetDocs:EmptyDescriptor", ...
            "The data descriptor '%s' is empty: the clone has no .ebrains-bucket.json to download it " + ...
            "with, or the file is empty in the bucket too. It is not converted.", ...
            descriptorFile)
        descriptorFile = "";
    end
end

function section = buildReadmeSection(project, datasetVersionUUID, datasetName, ...
        cloneFolder, descriptorFile, docFiles, dsmConfigFile)
%buildReadmeSection - The lines of the README section that describes the dataset

    section = ["## Dataset"; ""];
    if strlength(datasetName) > 0
        section = [section; datasetName; ""];
    end

    section = [section
        "- EBRAINS dataset version: `" + datasetVersionUUID + "`"
        "- Local clone: `" + cloneFolder + "`. Its files are empty placeholders until they are " + ...
            "downloaded. The bucket they come from is named in `.ebrains-bucket.json` in the clone."];
    if strlength(dsmConfigFile) > 0
        section = [section; "- Dataset Structure Model config: `" + dsmConfigFile + "`"];
    end

    section = [section; ""; "### Documents"; ""];
    [~, ~, extensions] = fileparts(docFiles);
    if any(endsWith(docFiles, "data-descriptor.md"))
        [~, name, extension] = fileparts(descriptorFile);
        section = [section; "- `docs/data-descriptor.md`: the data descriptor of the dataset, " + ...
            "converted from `" + name + extension + "`."];
    end
    if any(extensions == ".jsonld")
        section = [section; "- `docs/kg-dataset-version.jsonld`: openMINDS metadata of the dataset " + ...
            "version from the EBRAINS Knowledge Graph, with two levels of linked instances " + ...
            "(subjects and their states, techniques, protocols, contributors)."];
    end
    if ~any(endsWith(docFiles, ["data-descriptor.md", ".jsonld"]))
        section = [section; "No documents were written."];
    end

    section = [section; ""; "### Tables"; ""; describeTables(project)];
    section = [section; ""; "### Data variables"; ""; describeVariables(project)];
    section = [section; ""; "### Loading data in MATLAB"; ""; describeLoading(project)];
end

function lines = describeTables(project)
%describeTables - One line per master table: its type, rows, class, CSV copy and columns
    catalog = project.MetaTableCatalog;
    lines = strings(0, 1);
    for typeName = ["session", "subject"]
        if ~catalog.hasMasterMetaTable(typeName)
            continue
        end
        metaTable = catalog.getMasterMetaTable(typeName);
        line = sprintf("- %s table: %d rows, class `%s`.", ...
            upperFirst(typeName), height(metaTable.entries), metaTable.MetaTableClass);

        [~, fileName] = fileparts(metaTable.filepath);
        if isfile(fullfile(fileparts(metaTable.filepath), fileName + ".csv"))
            line = line + " CSV copy: `metadata/tables/" + fileName + ".csv`.";
        end

        columnNames = setdiff(string(metaTable.entries.Properties.VariableNames), ...
            ["DataLocation", "Progress", "Notebook"], 'stable');
        line = line + " Columns: " + strjoin("`" + columnNames + "`", ", ") + ".";
        lines(end+1, 1) = line; %#ok<AGROW>
    end
    if isempty(lines)
        lines = "The project has no session or subject table.";
    end
end

function lines = describeVariables(project)
%describeVariables - A Markdown table of the data variables and what loading them returns

    variables = project.VariableModel.Data;
    variables = variables(~[variables.IsInternal]);
    if isempty(variables)
        lines = "The project has no data variables.";
        return
    end

    % The full name of an adapter lets a reader look up what it returns
    % with help
    adapters = nansen.dataio.listFileAdapters();
    lines = ["| Variable | Description | Data location | File name expression | File adapter | Loads as |"
             "|---|---|---|---|---|---|"];
    for variable = reshape(variables, 1, [])
        description = "";
        if isfield(variable, 'Description')
            % A | would end the table cell
            description = replace(string(variable.Description), "|", "\|");
        end
        isAdapter = strcmp({adapters.FileAdapterName}, variable.FileAdapter);
        if strcmp(variable.FileAdapter, 'Default')
            adapterName = "Default";
            loadsAs = "MATLAB `load`, which reads .mat files only";
        elseif any(isAdapter)
            adapter = adapters(find(isAdapter, 1));
            adapterName = "`" + adapter.FunctionName + "`";
            loadsAs = string(adapter.DataType);
        else
            adapterName = string(variable.FileAdapter);
            loadsAs = "";
        end
        lines(end+1, 1) = sprintf("| `%s` | %s | %s | `%s` | %s | %s |", variable.VariableName, ...
            description, variable.DataLocation, fullfile(variable.Subfolder, variable.FileNameExpression), ...
            adapterName, loadsAs); %#ok<AGROW>
    end
end

function lines = describeLoading(project)
%describeLoading - MATLAB code that loads a variable of the first session

    variables = project.VariableModel.Data;
    variables = variables(~[variables.IsInternal]);
    if isempty(variables)
        exampleVariable = "variableName";
    else
        exampleVariable = string(variables(1).VariableName);
    end

    preferences = project.Preferences;
    isAutoDownload = isfield(preferences, 'AutoDownloadRemoteFiles') && preferences.AutoDownloadRemoteFiles;
    if isAutoDownload
        downloadLine = "% The project downloads a file when it is loaded (AutoDownloadRemoteFiles is true)";
    else
        downloadLine = "session.downloadDataFile(""" + exampleVariable + """)  " + ...
            "% Or project.setAutoDownloadRemoteFiles(true) to download when loading";
    end

    exampleSession = "<session id>";
    if project.MetaTableCatalog.hasMasterMetaTable('session')
        sessionTable = project.MetaTableCatalog.getMasterMetaTable('session');
        if height(sessionTable.entries) > 0
            exampleSession = string(sessionTable.entries.sessionID{1});
        end
    end

    lines = [
        "See `AGENTS.md` for how to download, load and save data. For example:"
        ""
        "```matlab"
        "nansen.ProjectManager().changeProject(""" + project.Name + """)"
        "project = nansen.getCurrentProject();"
        "session = project.getSessionObjects(""" + exampleSession + """);"
        downloadLine
        "data = session.loadData(""" + exampleVariable + """);"
        "```"];
end

function writeReadmeSection(readmeFile, section)
%writeReadmeSection - Put the section between its markers in README.md, replacing an earlier one

    startMarker = "<!-- sharebrain-dataset-start -->";
    endMarker = "<!-- sharebrain-dataset-end -->";
    block = strjoin([startMarker; section; endMarker], newline);

    readme = "";
    if isfile(readmeFile)
        readme = string(fileread(readmeFile));
    end

    if contains(readme, startMarker) && contains(readme, endMarker)
        before = extractBefore(readme, startMarker);
        after = extractAfter(readme, endMarker);
        readme = before + block + after;
    else
        readme = strip(readme, 'right') + newline + newline + block;
    end
    writelines(strip(readme, 'right'), readmeFile, WriteMode="overwrite")
end

function text = upperFirst(text)
    text = upper(extractBefore(text, 2)) + extractAfter(text, 1);
end
