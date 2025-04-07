sharebrainRootFolder = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(sharebrainRootFolder, 'tools')))

sharebrain_installMatBox()
matbox.installRequirements(sharebrainRootFolder)

% Run nansen_install to install all nansen's dependencies
nansen_install()

!pip install ebrains-kg-core
!pip install fairgraph
