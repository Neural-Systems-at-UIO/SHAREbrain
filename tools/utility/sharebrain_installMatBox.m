function installMatBox()
    % installMatBox - Install MatBox from latest release

    addonsTable = matlab.addons.installedAddons();
    isMatchedAddon = addonsTable.Name == "MatBox";

    if ~isempty(isMatchedAddon) && any(isMatchedAddon)
        matlab.addons.enableAddon('MatBox')
    else
        info = webread('https://api.github.com/repos/ehennestad/MatBox/releases/latest');
        assetNames = {info.assets.name};
        isMltbx = startsWith(assetNames, 'MatBox');

        mltbx_URL = info.assets(isMltbx).browser_download_url;

        % Download matbox
        tempFilePath = websave(tempname, mltbx_URL);
        cleanupObj = onCleanup(@(fp) delete(tempFilePath));

        % Install toolbox
        matlab.addons.install(tempFilePath);
    end
end