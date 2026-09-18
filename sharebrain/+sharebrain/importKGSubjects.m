function report = importKGSubjects(datasetVersionUUID, options)
%importKGSubjects - Fill a NANSEN project's subject table and subject states from the EBRAINS Knowledge Graph
%   report = sharebrain.importKGSubjects(datasetVersionUUID) downloads the
%   subjects that the EBRAINS dataset version lists as studied specimens
%   (openMINDS Subject, with its states) and fills two tables of the
%   current NANSEN project:
%
%     Subject table - one row per subject ID in the session table. A row
%       whose SubjectID equals the internalIdentifier of a Knowledge Graph
%       subject gets its BiologicalSex, Species, Strain, KGInstanceId and
%       KGLookupLabel. A project without a subject table gets one of class
%       sharebrain.metadata.type.Subject.
%
%     Session table - a subject with one state gives the state's age, age
%       category, weight and attributes to every session of that subject,
%       in the columns of sharebrain.metadata.type.Session. A subject with
%       several states gives none, because the Knowledge Graph does not
%       say which state holds during which session.
%
%   Subject IDs are matched exactly, never by similarity.
%
%   report = sharebrain.importKGSubjects(..., Name=Value) also specifies:
%       SubjectIdAliases - Dictionary from a project subject ID to the
%           internalIdentifier of the Knowledge Graph subject, for datasets
%           whose file names spell the subject differently, e.g.
%           dictionary(["m1" "m2"], ["MM-M1" "MM-M2"]).
%       Project - NANSEN project to fill. Default is the current project.
%
%   report is a table with one row per subject from either side, with the
%   variables SubjectID, KGInternalIdentifier, NumSessions, NumStates and
%   Note. Note says why a subject was not matched or its state not
%   applied, and is empty otherwise.
%
%   The dataset version is downloaded with two levels of links resolved
%   (kgpull), which takes about half a minute; links the Knowledge Graph
%   cannot return are skipped.
%
%   See also sharebrain.metadata.type.Subject,
%   sharebrain.metadata.type.Session, kgpull

    arguments
        datasetVersionUUID (1,1) string {omkg.validator.mustBeValidKGIdentifier}
        options.SubjectIdAliases (1,1) dictionary = dictionary(string.empty, string.empty)
        options.Project = nansen.getCurrentProject()
    end

    catalog = options.Project.MetaTableCatalog;
    if ~hasMasterTable(catalog, "session")
        error("SHAREbrain:ImportKGSubjects:NoSessionTable", ...
            "The project '%s' has no session table. Create the session table " + ...
            "before importing subjects from the Knowledge Graph.", options.Project.Name)
    end
    sessionTable = catalog.getMasterMetaTable('session');

    kgSubjects = downloadSubjects(datasetVersionUUID);
    kgIds = string({kgSubjects.InternalIdentifier});

    sessionSubjectIds = string(sessionTable.entries.subjectID);
    projectIds = unique(sessionSubjectIds(strlength(sessionSubjectIds) > 0))';
    matchIds = projectIds;
    hasAlias = isKey(options.SubjectIdAliases, projectIds);
    matchIds(hasAlias) = options.SubjectIdAliases(projectIds(hasAlias));
    [isMatched, kgIndex] = ismember(matchIds, kgIds);

    if isempty(projectIds)
        % The project's sessions name no subject, so there is no row to
        % fill; the report lists the Knowledge Graph subjects.
        report = buildReport(projectIds, matchIds, isMatched, kgIndex, kgSubjects, sessionSubjectIds);
        return
    end

    subjectTable = getSubjectTable(catalog, projectIds, options.Project);
    for i = find(isMatched)
        fillSubjectRow(subjectTable, projectIds(i), kgSubjects(kgIndex(i)))
    end
    subjectTable.save()

    ensureStateColumns(sessionTable)
    for i = find(isMatched)
        states = kgSubjects(kgIndex(i)).States;
        if isscalar(states)
            rowIndices = find(sessionSubjectIds == projectIds(i))';
            fillSessionRows(sessionTable, rowIndices, states)
        end
    end
    sessionTable.save()

    report = buildReport(projectIds, matchIds, isMatched, kgIndex, kgSubjects, sessionSubjectIds);
end

function subjects = downloadSubjects(datasetVersionUUID)
%downloadSubjects - The openMINDS subjects of a dataset version, reduced to the values the tables hold

    datasetVersion = kgpull(datasetVersionUUID, NumLinksToResolve=2);
    specimens = datasetVersion.studiedSpecimen;

    subjects = struct('InternalIdentifier', {}, 'InstanceId', {}, 'LookupLabel', {}, ...
        'Species', {}, 'Strain', {}, 'BiologicalSex', {}, 'States', {});
    for i = 1:numel(specimens)
        specimen = unwrap(specimens(i));
        if ~isa(specimen, 'openminds.core.research.Subject')
            continue % Subject groups, tissue samples and links that were not returned
        end
        [species, strain] = speciesNames(specimen.species);
        subjects(end+1) = struct( ...
            'InternalIdentifier', string(specimen.internalIdentifier), ...
            'InstanceId', instanceUUID(specimen.id), ...
            'LookupLabel', string(specimen.lookupLabel), ...
            'Species', species, ...
            'Strain', strain, ...
            'BiologicalSex', termName(specimen.biologicalSex), ...
            'States', stateValues(specimen.studiedState)); %#ok<AGROW>
    end
end

function states = stateValues(studiedStates)
%stateValues - Age, age category, weight and attributes of each subject state

    states = struct('InstanceId', {}, 'Age', {}, 'AgeCategory', {}, 'Weight', {}, 'Attributes', {});
    for i = 1:numel(studiedStates)
        state = unwrap(studiedStates(i));
        if ~isa(state, 'openminds.core.research.SubjectState')
            continue % A state the Knowledge Graph did not return
        end
        attributes = strings(1, 0);
        for j = 1:numel(state.attribute)
            attributes(end+1) = termName(state.attribute(j)); %#ok<AGROW>
        end
        states(end+1) = struct( ...
            'InstanceId', instanceUUID(state.id), ...
            'Age', formatQuantity(state.age), ...
            'AgeCategory', termName(state.ageCategory), ...
            'Weight', formatQuantity(state.weight), ...
            'Attributes', strjoin(attributes(strlength(attributes) > 0), ", ")); %#ok<AGROW>
    end
end

function subjectTable = getSubjectTable(catalog, projectIds, project)
%getSubjectTable - The master subject table, created or extended to hold every project subject ID

    if ~hasMasterTable(catalog, "subject")
        subjectArray = createSubjects(projectIds);
        subjectTable = nansen.metadata.MetaTable.new(subjectArray);
        S = struct('MetaTableName', subjectTable.createDefaultName, ...
            'MetaTableClass', 'sharebrain.metadata.type.Subject', ...
            'IsDefault', false, 'IsMaster', true);
        catalog.registerMetaTable(subjectTable, S);
        return
    end

    subjectTable = catalog.getMasterMetaTable('subject');
    for columnName = ["KGInstanceId", "KGLookupLabel"]
        if ~ismember(columnName, subjectTable.entries.Properties.VariableNames)
            subjectTable.addTableVariable(columnName, {''})
        end
    end
    newIds = setdiff(projectIds, string(subjectTable.entries.SubjectID));
    if ~isempty(newIds)
        newSubjectTable = nansen.metadata.MetaTable.new(createSubjects(newIds));
        project.synchronizeMetaTableVariables(newSubjectTable);
        subjectTable.addTable(newSubjectTable.entries)
    end
end

function subjectArray = createSubjects(subjectIds)
%createSubjects - Subject objects with only their SubjectID set
    subjectArray(numel(subjectIds)) = sharebrain.metadata.type.Subject();
    for i = 1:numel(subjectIds)
        subjectArray(i).SubjectID = char(subjectIds(i));
    end
end

function fillSubjectRow(subjectTable, subjectId, kgSubject)
%fillSubjectRow - Write the Knowledge Graph values of one subject into its row
    rowIndex = find(string(subjectTable.entries.SubjectID) == subjectId, 1);
    values = struct('BiologicalSex', kgSubject.BiologicalSex, 'Species', kgSubject.Species, ...
        'Strain', kgSubject.Strain, 'KGInstanceId', kgSubject.InstanceId, ...
        'KGLookupLabel', kgSubject.LookupLabel);
    for columnName = string(fieldnames(values))'
        subjectTable.editEntries(rowIndex, columnName, char(values.(columnName)))
    end
end

function ensureStateColumns(sessionTable)
%ensureStateColumns - Add the subject state columns to a session table that lacks them
    for columnName = ["SubjectAge", "SubjectAgeCategory", "SubjectWeight", "SubjectAttributes", "SubjectStateKGId"]
        if ~ismember(columnName, sessionTable.entries.Properties.VariableNames)
            sessionTable.addTableVariable(columnName, {''})
        end
    end
end

function fillSessionRows(sessionTable, rowIndices, state)
%fillSessionRows - Write the values of one subject state into sessions of its subject
    values = struct('SubjectAge', state.Age, 'SubjectAgeCategory', state.AgeCategory, ...
        'SubjectWeight', state.Weight, 'SubjectAttributes', state.Attributes, ...
        'SubjectStateKGId', state.InstanceId);
    for rowIndex = rowIndices
        for columnName = string(fieldnames(values))'
            sessionTable.editEntries(rowIndex, columnName, char(values.(columnName)))
        end
    end
end

function report = buildReport(projectIds, matchIds, isMatched, kgIndex, kgSubjects, sessionSubjectIds)
%buildReport - One row per project subject and per Knowledge Graph subject without sessions

    numProject = numel(projectIds);
    report = table('Size', [numProject, 5], ...
        'VariableTypes', ["string", "string", "double", "double", "string"], ...
        'VariableNames', ["SubjectID", "KGInternalIdentifier", "NumSessions", "NumStates", "Note"]);
    for i = 1:numProject
        report.SubjectID(i) = projectIds(i);
        report.NumSessions(i) = sum(sessionSubjectIds == projectIds(i));
        report.Note(i) = "";
        if isMatched(i)
            numStates = numel(kgSubjects(kgIndex(i)).States);
            report.KGInternalIdentifier(i) = matchIds(i);
            report.NumStates(i) = numStates;
            if numStates ~= 1
                report.Note(i) = sprintf("The subject has %d states; none was applied to its sessions.", numStates);
            end
        else
            report.KGInternalIdentifier(i) = "";
            report.NumStates(i) = NaN;
            report.Note(i) = "No Knowledge Graph subject has the internalIdentifier " + matchIds(i) + ".";
        end
    end

    unmatchedKg = setdiff(1:numel(kgSubjects), kgIndex(isMatched));
    for k = unmatchedKg
        report(end+1, :) = {"", kgSubjects(k).InternalIdentifier, 0, numel(kgSubjects(k).States), ...
            "No session of the project has this subject."}; %#ok<AGROW>
    end
end

function tf = hasMasterTable(catalog, typeName)
%hasMasterTable - Whether the catalog has a master table whose class name contains typeName
    tf = any(catalog.Table.IsMaster & contains(string(catalog.Table.MetaTableClass), typeName, 'IgnoreCase', true));
end

function [species, strain] = speciesNames(value)
%speciesNames - Species and strain names of a subject's species, which is a Species or a Strain
    value = unwrap(value);
    species = "";
    strain = "";
    if isa(value, 'openminds.core.research.Strain')
        strain = string(value.name);
        species = termName(value.species);
    elseif isa(value, 'openminds.controlledterms.Species')
        species = string(value.name);
    end
end

function name = termName(value)
%termName - Name of a controlled term, or "" when it is unset or was not resolved
    value = unwrap(value);
    name = "";
    if ~isempty(value) && isprop(value, 'name') && ~isempty(value.name)
        name = string(value.name);
    end
end

function text = formatQuantity(value)
%formatQuantity - A quantitative value or range as text with its unit, e.g. "3 month", "400-500 gram"
    value = unwrap(value);
    text = "";
    if isa(value, 'openminds.core.miscellaneous.QuantitativeValue') && ~isempty(value.value)
        text = strtrim(string(value.value) + " " + termName(value.unit));
    elseif isa(value, 'openminds.core.miscellaneous.QuantitativeValueRange') && ~isempty(value.minValue)
        text = string(value.minValue) + "-" + string(value.maxValue);
        text = strtrim(text + " " + termName(value.maxValueUnit));
    end
end

function uuid = instanceUUID(identifier)
%instanceUUID - The UUID of a Knowledge Graph instance IRI
    uuid = string(identifier);
    if contains(uuid, "instances/")
        uuid = extractAfter(uuid, "instances/");
    end
end

function value = unwrap(value)
%unwrap - The instance held by an openMINDS mixed-type element
    if ~isempty(value) && isprop(value, 'Instance')
        value = value.Instance;
    end
end
