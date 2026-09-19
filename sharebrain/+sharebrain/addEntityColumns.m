function report = addEntityColumns(dsmConfigFile, cloneFolder, options)
%addEntityColumns - Add the identities of a session's parent entities to the session table
%   report = sharebrain.addEntityColumns(dsmConfigFile, cloneFolder) walks
%   the dataset cloned into cloneFolder with the Dataset Structure Model
%   dsmConfigFile and gives the session table of the current NANSEN project
%   one column per identity field of the entities that a session belongs
%   to, other than the subject. In garad-2022, for example, a session is a
%   recording, and each recording belongs to a cell, so the table gets the
%   column cell_id.
%
%   A session is matched to the DSM record that has its file or folder:
%   the record's path in a data location equals the session's path in the
%   NANSEN data location made from it, which the DSM converter names
%   matlab.lang.makeValidName(<identifier>) (fmri-vta-em becomes
%   fmri_vta_em). Where several records have the path, the one with the
%   most parents is used.
%
%   The root storage paths of the model are placeholders,
%   /data/ebrains/<bucket>/..., which are mapped to cloneFolder as the seed
%   script maps them for the import.
%
%   report = sharebrain.addEntityColumns(..., Project=PROJECT) fills the
%   session table of PROJECT instead of the current project.
%
%   report is a struct with the fields Columns (names of the columns that
%   were added or filled), NumSessions and NumMatched (sessions that were
%   matched to a record).
%
%   Sessions detected after this function has run have empty values in
%   these columns until it runs again.
%
%   Requires the MATLAB reader of the Dataset Structure Model (the dsm
%   namespace) on the path.
%
%   See also dsm.walk, sharebrain.importKGSubjects

    arguments
        dsmConfigFile (1,1) string {mustBeFile}
        cloneFolder (1,1) string {mustBeFolder}
        options.Project = nansen.getCurrentProject()
    end

    records = walkClone(dsmConfigFile, cloneFolder);
    recordsByPath = indexRecordsByPath(records);

    sessionTable = options.Project.MetaTableCatalog.getMasterMetaTable('session');
    numSessions = height(sessionTable.entries);
    parentIdentities = cell(numSessions, 1);
    isMatched = false(numSessions, 1);
    for i = 1:numSessions
        record = findRecord(sessionTable.entries.DataLocation(i, :), recordsByPath);
        isMatched(i) = ~isempty(record);
        parentIdentities{i} = parentIdentityValues(record);
    end

    columnNames = strings(1, 0);
    for i = 1:numSessions
        columnNames = [columnNames, reshape(string(fieldnames(parentIdentities{i})), 1, [])]; %#ok<AGROW>
    end
    columnNames = unique(columnNames, 'stable');
    for columnName = reshape(columnNames, 1, [])
        if ~ismember(columnName, sessionTable.entries.Properties.VariableNames)
            sessionTable.addTableVariable(columnName, {''})
        end
        for i = 1:numSessions
            if isfield(parentIdentities{i}, columnName)
                sessionTable.editEntries(i, columnName, char(parentIdentities{i}.(columnName)))
            end
        end
    end
    sessionTable.save()

    report = struct('Columns', columnNames, 'NumSessions', numSessions, ...
        'NumMatched', sum(isMatched));
end

function records = walkClone(dsmConfigFile, cloneFolder)
%walkClone - The DSM entity records of a cloned dataset
    config = dsm.loadConfig(dsmConfigFile);
    model = jsondecode(fileread(dsmConfigFile));

    roots = {};
    for dataLocation = reshape(asCell(model.dataLocations), 1, [])
        location = dataLocation{1};
        for rootStoragePath = reshape(asCell(location.filesystemSource.rootStoragePaths), 1, [])
            rootPath = rootStoragePath{1};
            localFolder = mapPlaceholder(string(rootPath.path), cloneFolder);
            if isfolder(localFolder)
                roots{end+1} = dsm.listing.fromDirectory(string(location.identifier), ...
                    string(rootPath.identifier), localFolder); %#ok<AGROW>
            end
        end
    end

    result = dsm.walk(config, dsm.Listing(roots));
    records = result.Records;
end

function recordsByPath = indexRecordsByPath(records)
%indexRecordsByPath - Records by "<data location>|<path>", the one with most parents for each key
%   The data location is named as the DSM converter names the NANSEN data
%   location, so that the keys match the session table's.
    recordsByPath = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for i = 1:numel(records)
        record = records{i};
        for j = 1:numel(record.locations)
            location = asStruct(record.locations, j);
            for path = reshape(string(location.paths), 1, [])
                locationName = matlab.lang.makeValidName(string(location.dataLocationIdentifier));
                key = char(locationName + "|" + strip(path, "/"));
                if ~isKey(recordsByPath, key) || ...
                        numel(record.parents) > numel(recordsByPath(key).parents)
                    recordsByPath(key) = record;
                end
            end
        end
    end
end

function record = findRecord(dataLocations, recordsByPath)
%findRecord - The record of a session, found by its path in any data location
    record = [];
    for j = 1:numel(dataLocations)
        subfolders = string(dataLocations(j).Subfolders);
        if isempty(subfolders) || strlength(subfolders) == 0
            continue
        end
        key = char(string(dataLocations(j).Name) + "|" + strip(replace(subfolders, "\", "/"), "/"));
        if isKey(recordsByPath, key)
            record = recordsByPath(key);
            return
        end
    end
end

function identities = parentIdentityValues(record)
%parentIdentityValues - The identity fields of a record's parents other than the subject
    identities = struct();
    if isempty(record)
        return
    end
    for j = 1:numel(record.parents)
        parent = asStruct(record.parents, j);
        if parent.entityType == "subject"
            continue
        end
        for name = reshape(string(fieldnames(parent.identity)), 1, [])
            identities.(name) = string(parent.identity.(name));
        end
    end
end

function localFolder = mapPlaceholder(placeholder, cloneFolder)
%mapPlaceholder - Replace /data/ebrains/<bucket> in a root path with the clone folder
    bucketPrefix = regexp(placeholder, "^/data/ebrains/[^/]+", "match", "once");
    if ismissing(bucketPrefix)
        error("SHAREbrain:AddEntityColumns:UnexpectedRootPath", ...
            "The root path '%s' is not a placeholder /data/ebrains/<bucket>/... . " + ...
            "Write the root paths of the DSM config in that form.", placeholder)
    end
    localFolder = fullfile(cloneFolder, extractAfter(placeholder, strlength(bucketPrefix)));
end

function items = asCell(value)
%asCell - A decoded JSON array as a cell array, whether jsondecode made a struct array or a cell
    if isstruct(value)
        items = num2cell(value);
    else
        items = value;
    end
end

function item = asStruct(values, index)
%asStruct - Element index of a list that is a cell array or a struct array
    if iscell(values)
        item = values{index};
    else
        item = values(index);
    end
end
