function project = initNansenProjectFromKGDataset(projectRoot, dataFolder, datasetVersionUUID, options)
%initNansenProjectFromKGDataset - Set up a NANSEN project for a KG dataset
%   initNansenProjectFromKGDataset(projectRoot,dataFolder,datasetVersionUUID)
%   creates a NANSEN project in the folder projectRoot and clones the file
%   hierarchy of the EBRAINS dataset version datasetVersionUUID into
%   dataFolder. The project is registered with NANSEN's project manager and
%   becomes the current project.
%
%   initNansenProjectFromKGDataset(...,Description=TEXT) describes the
%   project as TEXT instead of by the dataset version it was created for.
%
%   initNansenProjectFromKGDataset(...,ReuseProjectIfExists=TF) continues
%   with a project that is already registered under the same name and root
%   instead of failing. Use this to rerun the function after the dataset
%   clone was interrupted. Default is false.
%
%   initNansenProjectFromKGDataset(...,Verbose=TF) reports progress while
%   the dataset is cloned.
%
%   PROJECT = initNansenProjectFromKGDataset(...) returns the project.
%
%   The project is created empty. Its data locations and metadata tables
%   still have to be configured by hand, since the folder organisation of a
%   cloned dataset is not known in advance.
%
%   The project is named after the last folder of projectRoot. That folder
%   name must be a valid MATLAB identifier, because it also names the
%   package folder that holds the project's code.
%
%   See also cloneKGDataset, nansen.config.project.ProjectManager

    arguments
        projectRoot (1,1) string
        dataFolder (1,1) string
        datasetVersionUUID (1,1) string {omkg.validator.mustBeValidKGIdentifier}
        options.Description (1,1) string = missing
        options.ReuseProjectIfExists (1,1) logical = false
        options.Verbose (1,1) logical = false
    end

    projectName = getProjectNameFromRoot(projectRoot);

    description = options.Description;
    if ismissing(description)
        description = sprintf(...
            "NANSEN project for EBRAINS dataset version %s", datasetVersionUUID);
    end

    % The project manager warns that no projects are available when this is
    % the first project on this machine, which is what is being fixed here.
    warnState = warning("off", "Nansen:NoProjectsAvailable");
    warningCleanup = onCleanup(@() warning(warnState));

    % Create the project before cloning. Project creation fails fast on a
    % name collision or an existing folder, whereas cloning a dataset is a
    % long network operation whose result would then be left orphaned.
    % A failed clone leaves the project behind, so a rerun can opt in to
    % reusing it rather than being blocked by the name collision.
    % Note: the arguments are passed as char because the project catalog
    % only recognises a project entry that is given as character vectors.
    projectManager = nansen.ProjectManager();
    existingProject = projectManager.getProject(char(projectName));

    if isempty(existingProject)
        projectManager.createProject(char(projectName), char(description), char(projectRoot))
    elseif options.ReuseProjectIfExists
        assertProjectRootMatches(existingProject, projectRoot)
        % createProject makes the new project current, so do the same here
        % to give the reuse path the same end state.
        projectManager.changeProject(char(projectName))
    else
        error("SHAREbrain:InitNansenProject:ProjectExists", ...
            "A NANSEN project named '%s' already exists. Set " + ...
            "ReuseProjectIfExists=true to continue with that project, or " + ...
            "choose a project root with a different last folder name.", ...
            projectName)
    end

    sharebrain.cloneKGDataset(dataFolder, datasetVersionUUID, ...
        Verbose=options.Verbose)

    if nargout > 0
        project = projectManager.getProjectObject(projectName);
    end
end

function assertProjectRootMatches(existingProject, projectRoot)
%assertProjectRootMatches - Error if a catalog entry lives at another root

    % Reusing a project that lives elsewhere would silently attach the
    % dataset to the wrong project, so the roots must match exactly.
    existingRoot = stripTrailingSeparators(string(existingProject.Path));
    requestedRoot = stripTrailingSeparators(projectRoot);

    if ~strcmp(existingRoot, requestedRoot)
        error("SHAREbrain:InitNansenProject:ProjectRootMismatch", ...
            "The existing project '%s' is located at '%s', not at the " + ...
            "requested project root '%s'. Pass the root of the existing " + ...
            "project to reuse it, or choose a project root with a " + ...
            "different last folder name.", ...
            existingProject.Name, existingRoot, requestedRoot)
    end
end

function projectName = getProjectNameFromRoot(projectRoot)
%getProjectNameFromRoot - Project name from the last folder of a root path

    projectRoot = stripTrailingSeparators(projectRoot);
    [~, projectName] = fileparts(projectRoot);

    try
        nansen.config.project.mustBeValidProjectName(projectName)
    catch cause
        ME = MException("SHAREbrain:InitNansenProject:InvalidProjectName", ...
            "The project is named after the last folder of the project " + ...
            "root, which here is '%s'. Choose a project root whose last " + ...
            "folder is a valid MATLAB identifier.", projectName);
        ME = ME.addCause(cause);
        throw(ME)
    end
end

function pathStr = stripTrailingSeparators(pathStr)
%stripTrailingSeparators - Drop trailing file separators from a path
%   fileparts reports an empty name for a path that ends in a separator,
%   and two spellings of the same folder must compare equal.
    pathStr = regexprep(pathStr, "[\\/]+$", "");
end
