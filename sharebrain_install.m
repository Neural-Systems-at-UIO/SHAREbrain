sharebrainRootFolder = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(sharebrainRootFolder, 'tools')))

sharebrain_installMatBox()
matbox.installRequirements(sharebrainRootFolder)

% Run nansen_install to install all nansen's dependencies
nansen_install()

try
    !pip install ebrains-kg-core
    !pip install fairgraph
catch ME
    if ismac
        try
            !pip3 install ebrains-kg-core
            !pip3 install fairgraph
            clear ME
        catch ME

        end
    end
    if exist('ME', 'var')
        rethrow(ME)
    end
end
