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

    % Run nansen_install to install additional nansen dependencies
    nansen_install()
end
