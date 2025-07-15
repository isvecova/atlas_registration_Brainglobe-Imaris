function XT_ImportBrainRegionIdentificators(aImarisApplicationID)

    % XT_ImportBrainRegionIdentificators - Loads identifications of brain regions from a labeled mask TIFF image and csv file with region names.
    % Usage: Requires brain atlas regions already loaded in Imaris using Import Segmentations/Labels function. 
    %        This extension loads identification of those regions from the same mask TIFF image and a csv matching region ids and names. 
    %       The csv file should contain these columns: region_id and region_name.
    %
    %  Installation:
    %
    %  - Copy this file into the XTensions folder in the Imaris installation directory
    %  - You will find this function in the Image Processing menu and in the XTension tab in Surfaces.
    %
    %    <CustomTools>
    %      <Menu>
    %        <Item name="Brain region identificators import" icon="Matlab" tooltip="Import brain region names and IDs from tiff and csv from BrainGlobe.">
    %          <Command>MatlabXT::XT_ImportBrainRegionIdentificators(%i)</Command>
    %        </Item>
    %      </Menu>
    %      <SurpassTab>
    %        <SurpassComponent name="bpSurfaces">
    %          <Item name="Brain region identificators import" icon="Matlab" tooltip="Import brain region names and IDs from tiff and csv from BrainGlobe.">
    %            <Command>MatlabXT::XT_ImportBrainRegionIdentificators(%i)</Command>
    %          </Item>
    %        </SurpassComponent>
    %      </SurpassTab>
    %    </CustomTools>
    % 
    %
    %  Description:
    %   
    %   Import brain region names and IDs
    %   Requires a mask tif file used to create surfaces, and csv mapping ids to brain region names.
    %
    %  Author: Iva Svecova (svecovaiva01@gmail.com), 2025
    %  Licensed under the Creative Commons Attribution 4.0 (CC BY 4.0) — see <https://creativecommons.org/licenses/by/4.0/>
    %  May be used, modified, and redistributed, provided attribution to the author is retained.
    %  Supplied “as is”, without warranties or liability.

    % Initialize and connect to Imaris
    if ~isa(aImarisApplicationID, 'Imaris.IApplicationPrxHelper')
        javaaddpath ImarisLib.jar;
        vImarisLib = ImarisLib;
        if ischar(aImarisApplicationID)
            aImarisApplicationID = round(str2double(aImarisApplicationID));
        end
        vImarisApplication = vImarisLib.GetApplication(aImarisApplicationID);
    else
        vImarisApplication = aImarisApplicationID;
    end

    % Get selected Surfaces object
    vSurpassComponent = vImarisApplication.GetSurpassSelection;
    if vImarisApplication.GetFactory.IsSurfaces(vSurpassComponent)
        vSurfaces = vImarisApplication.GetFactory.ToSurfaces(vSurpassComponent);
    else
        msgbox('Please select a Surface object created from a label image.');
        return;
    end

    % Ask user to select the original label image (TIFF)
    [vFileName, vPathName] = uigetfile({'*.tif;*.tiff','Label TIFF Files (*.tif, *.tiff)'}, ...
        'Select the brain atlas mask');
    if isequal(vFileName, 0)
        return;
    end
    vFilePath = fullfile(vPathName, vFileName);


    % Ask user to select the CSV file with brain region names and acronyms
    [csvFileName, csvPathName] = uigetfile({'*.csv','CSV Files (*.csv)'}, ...
        'Select the csv file containing region IDs and corresponding names');
    if isequal(csvFileName, 0)
        return;
    end
    csvFilePath = fullfile(csvPathName, csvFileName);

    % Read the label image
    try
        disp('Reading label image...');
        vLabelImage = tiffreadVolume(vFilePath);
    catch
        msgbox('Failed to read TIFF. Ensure it is a 3D label image.');
        return;
    end

    % Read the CSV file
    try
        disp('Reading CSV file...');
        tbl = readtable(csvFilePath);
    catch
        msgbox('Failed to read CSV. Ensure it is a valid CSV.');
        return;
    end

    % Check required columns
    requiredCols = {'region_id', 'region_name'};
    if ~all(ismember(requiredCols, lower(tbl.Properties.VariableNames)))
        msgbox('CSV must contain columns: region_id, region_name.');
        return;
    end

    % Get surface data
    vNumSurfaces = vSurfaces.GetNumberOfSurfaces;

    % If the number of surfaces is higher than 500, ask the user to confirm they want to proceed
    if vNumSurfaces > 500
        answer = questdlg(['You have ' num2str(vNumSurfaces) ' surfaces. This may take a while. Do you want to proceed?'], ...
            'Confirm', 'Yes', 'No', 'No');
        if strcmp(answer, 'No')
            return;
        end
    end

    % Get mask voxel size
    vDataSet = vImarisApplication.GetDataSet();
    vMaskSize = size(vLabelImage);   % in order y, x, z

    vMinX = 0;
    vMinY = 0;
    vMinZ = 0;
    vMaxX = vDataSet.GetExtendMaxX();
    vMaxY = vDataSet.GetExtendMaxY();
    vMaxZ = vDataSet.GetExtendMaxZ();
    vSizeX = vMaskSize(2);
    vSizeY = vMaskSize(1);
    vSizeZ = vMaskSize(3);

    vLabelIds = zeros(1, vNumSurfaces);
    vRegionNames = cell(1, vNumSurfaces);

    % Create dictionary for faster region name retrieval
    regionLookup = dictionary(tbl.region_id, tbl.region_name);

    % Convert coordinates to voxel indices and read label IDs
    for i = 1:vNumSurfaces

        if mod(i, 10) == 0  % Progress update every 10 surfaces
            disp(['Processing surface ' num2str(i) ' of ' num2str(vNumSurfaces)]);
        end

        % Get single mask as IDataSet over full dataset size
        vMaskDataSet = vSurfaces.GetSingleMask(i - 1, vMinX, vMinY, vMinZ, vMaxX, vMaxY, vMaxZ, vSizeX, vSizeY, vSizeZ);
        vRaw = vMaskDataSet.GetDataVolumeAs1DArrayBytes(0, 0);

        maskIndices = find(uint8(vRaw));

        if isempty(maskIndices)
            vLabelIds(i) = -1;
            vRegionNames(i) = {''};
            continue;
        end

        % Convert linear indices to subscripts in one call
        [xx, yy, zz] = ind2sub([vSizeX, vSizeY, vSizeZ], maskIndices);

        % Vectorized boundary checking
        validMask = (xx >= 1 & xx <= size(vLabelImage,2) & ...
                    yy >= 1 & yy <= size(vLabelImage,1) & ...
                    zz >= 1 & zz <= size(vLabelImage,3));
        
        if ~any(validMask)
            vLabelIds(i) = -1;
            vRegionNames(i) = {''};
            continue;
        end

        % Filter coordinates to valid ones only
        xx = xx(validMask);
        yy = yy(validMask);
        zz = zz(validMask);
        
        % Sample a subset of points for large surfaces (optimization for speed)
        maxSampleSize = 5000;  % Adjust based on your needs
        if length(xx) > maxSampleSize
            sampleIdx = randperm(length(xx), maxSampleSize);
            xx = xx(sampleIdx);
            yy = yy(sampleIdx);
            zz = zz(sampleIdx);
        end
        
        % Vectorized label extraction using linear indexing
        linearIndices = sub2ind(size(vLabelImage), yy, xx, zz);
        labels = vLabelImage(linearIndices);
        
        % Remove zero labels (background)
        labels = labels(labels > 0);

        if isempty(labels)
            vLabelIds(i) = -1;
            vRegionNames(i) = {''};
        else
            regionId = mode(labels);
            vLabelIds(i) = regionId;  

            % Name lookup using the dictionary
            if isKey(regionLookup, regionId)
                vRegionNames(i) = {regionLookup(regionId)};
            else
                vRegionNames(i) = {'Unknown'};
            end

            % Set labels in Imaris
            vDataItem = vImarisApplication.GetSurpassSelection;
            vLabel = vImarisApplication.GetFactory.CreateObjectLabel(i-1, "Brain region", vRegionNames{i});
            vDataItem.SetLabel(vLabel);
        end
    end

    % Write label IDs as custom statistics
    disp('Adding the statistics column...')
    vInd = 1:numel(vLabelIds);   % The dimensions of the input must be 1xn - nx1 did not work
    vNames(vInd) = {'Region ID'};
    vLabelIds = vLabelIds';
    vUnits(vInd) = {''};
    vFactors(vInd) = {'Surface'};    % This assigns the information that the value belongs to a surface
    vFactorNames = {'Category'};
    vIds = vSurfaces.GetIds;

    vSurfaces.AddStatistics(vNames, vLabelIds, vUnits, vFactors, vFactorNames, vIds);

    msgbox('Brain region IDs have been imported to Statistics and brain region names to Labels.', 'Done');

end
