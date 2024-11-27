sharebrainRootFolder = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(sharebrainRootFolder, 'tools')))

sharebrain_installMatBox()
matbox.installRequirements(sharebrainRootFolder)
