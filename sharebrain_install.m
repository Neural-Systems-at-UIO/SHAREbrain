function sharebrain_install(flags)

    arguments (Repeating)
        flags (1,1) string
    end

    flags = [flags{:}];
    doUpdate = any(strcmp(flags, {'--u', '-update'}));
    
    sharebrainRootFolder = fileparts(mfilename('fullpath'));
    addpath(genpath(fullfile(sharebrainRootFolder, 'tools')))
    
    sharebrain_installMatBox()
    if doUpdate
        matbox.installRequirements(sharebrainRootFolder, 'update')
    else
        matbox.installRequirements(sharebrainRootFolder)
    end

    assertValidMatNWBInstallation()

    % Run matnwb's generateCore
    generateCore()

    % Run nansen_install to install additional nansen dependencies
    nansen_install()
end

function assertValidMatNWBInstallation()
    % Check if new version of MatNWB is on users path and warn
    probeName = fullfile("+types", "+core", "TimeSeries.m");
    s = which(probeName);
    if ~isempty(s)
        error("SHAREbrain:Install:IncompatibleMatNWBVersion", ...
            ['SHAREbrain is currently relying on a forked version of ', ...
            'MatNWB. Please remove the following version of MatNWB from you ', ...
            'path when working with SHAREbrain: %s'], replace(s, probeName, "") )
    end
end
