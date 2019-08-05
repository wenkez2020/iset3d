function [assetsPosList, assets] = piTrafficPlace(trafficflow, varargin)
% Place assets with the Sumo trafficflow information
%
% Syntax:
%   [assetsPosList, assets] = piTrafficPlace(trafficflow, [varargin])
%
% Description:
%    SUMO generates trafficflow at a series of timesteps. We choose one or
%    multiple timestamps, find the number and class of vehicles for
%    this/these timestamp(s) on the road. Download assets with respect to
%    the number and class. The types of objects placed are:
%        cars, buses, pedestrians, bikes, trucks
%
% Inputs:
%    trafficflow   - Struct. A structure containing the data generated by
%                    SUMO/SUSO. The structure contains position and
%                    orientation information.
%
% Outputs:
%    assetsPosList - Array. Positions of the placed objects
%    assets        - Array. A list of all of the placed objects.
%
% Optional key/value pairs:
%    nScene        - Numeric. The scene number. Default 1.
%    timeStamp     - Numeric. Traffic simulation time stamp. Default [].
%    trafficLight  - String. A string representing the color of a traffic
%                    light. Default is 'red'.
%    resources     - Boolean. Whether or not to download external
%                    resources. Default true.
%    scitran       - Object. A scitran object. The default is [], and then
%                    pulls an instance of 'stanfordlabs'.
%

% History:
%    XX/XX/XX  ZL   Author: Zhenyi Liu (ZL)
%    04/05/19  JNM  Documentation pass
%    04/19/19  JNM  Merge with master (resolve conflicts)
%    05/09/19  JNM  Merge with master again

%% Parse parameterss
p = inputParser;
if length(varargin) > 1
    for i = 1:length(varargin)
        if ~(isnumeric(varargin{i}) | islogical(varargin{i}) | ...
                isobject(varargin{i}))
            varargin{i} = ieParamFormat(varargin{i});
        end
    end
else
    varargin = ieParamFormat(varargin);
end

p.addParameter('nScene', 1);
p.addParameter('timestamp', []);
p.addParameter('scitran', []);
p.addParameter('trafficlight', 'red');
p.addParameter('resources', true);
p.parse(varargin{:});

nScene = p.Results.nScene;
timestamp = p.Results.timestamp;
trafficlight = p.Results.trafficlight;
resources = p.Results.resources;
st = p.Results.scitran;

if isempty(st), st = scitran('stanfordlabs'); end

%% Download asssets with respect to the number and class of Sumo output.
if isfield(trafficflow(timestamp).objects, 'car') || ...
        isfield(trafficflow(timestamp).objects, 'passenger')
    ncars = length(trafficflow(timestamp).objects.car);
    % [~, carList] = piAssetListCreate('class', 'car', 'scitran', st);
else
    ncars = 0;
end

if isfield(trafficflow(timestamp).objects, 'pedestrian')
    nped = length(trafficflow(timestamp).objects.pedestrian);
    % [~, pedList] = piAssetListCreate('class', 'pedestrian', ...
    %     'scitran', st);
else
    nped = 0;
end

if isfield(trafficflow(timestamp).objects, 'bus')
    nbuses = length(trafficflow(timestamp).objects.bus);
    % [~, busList] = piAssetListCreate('class', 'bus', 'scitran', st);
else
    nbuses = 0;
end

if isfield(trafficflow(timestamp).objects, 'truck')
    ntrucks = length(trafficflow(timestamp).objects.truck);
    % [~, truckList] = piAssetListCreate('class', 'truck', 'scitran', st);
else
    ntrucks = 0;
end

if isfield(trafficflow(timestamp).objects, 'bicycle')
    nbikes = length(trafficflow(timestamp).objects.bicycle);
    % [~, bikeList] = piAssetListCreate('class', 'bike', 'scitran', st);
else
    nbikes = 0;
end

% Description of the assets
assets = piAssetCreate('ncars', ncars, 'nped', nped, 'nbuses', nbuses, ...
    'ntrucks', ntrucks, 'nbikes', nbikes, 'resources', resources, ...
    'scitran', st);

%% Classified mobile object positions.
% Buildings and trees are static objects, placed separately
assets_updated = assets;
if nScene == 1
    assetClassList = fieldnames(assets);
    for hh = 1:length(assetClassList)
        assetClass = assetClassList{hh};
        order = randperm(...
            numel(trafficflow(timestamp).objects.(assetClass)));
        for jj = 1:numel(trafficflow(timestamp).objects.(assetClass))
            assets_shuffled.(assetClass)(jj) = trafficflow(...
                timestamp).objects.(assetClass)(order(jj)); % target assets
        end
        index = 1;
        % In order to correctly add motion blur to the final rendering, we
        % need to find out the translation and rotation of the object on
        % the next timestamp, in another words, where the object is going.
        % And to do that, we need compare the object name of this timestamp
        % with the object name of next timestamp, extract the start and end
        % transformation of both.
        for jj = 1:length(assets_shuffled.(assetClass))
             assets_shuffled.(assetClass)(jj).motion = [];
             try
                 for ii = 1:numel(...
                         trafficflow(timestamp + 1).objects.(assetClass))
                     if strcmp(assets_shuffled.(assetClass)(jj).name, ...
                             trafficflow(timestamp + 1).objects.(...
                             assetClass)(ii).name)
                         assets_shuffled.(assetClass)(jj).motion.pos = ...
                             trafficflow(timestamp+1).objects.(...
                             assetClass)(ii).pos;
                         assets_shuffled.(assetClass)(...
                             jj).motion.orientation = trafficflow(...
                             timestamp + 1).objects.(...
                             assetClass)(ii).orientation;
                         assets_shuffled.(assetClass)(...
                             jj).motion.slope = trafficflow(...
                             timestamp + 1).objects.(assetClass)(ii).slope;
                     end
                 end
             catch
                 fprintf('% not found in next timestamp \n', assetClass);
             end
             if isempty(assets_shuffled.(assetClass)(jj).motion)
                 % there are cases when a car is going out of boundary or
                 % some else reason, sumo decides to kill this car, so in
                 % these cases, the motion info remains empty so we should
                 % estimate by speed information;
                 from = assets_shuffled.(assetClass)(jj).pos;
                 distance = assets_shuffled.(assetClass)(jj).speed;
                 orientation = assets_shuffled.(assetClass)(...
                     jj).orientation;
                 to(1) = from(1) + distance * cosd(orientation);
                 to(2) = from(2);
                 to(3) = from(3) - distance * sind(orientation);
                 assets_shuffled.(assetClass)(jj).motion.pos = to;
                 assets_shuffled.(assetClass)(jj).motion.orientation = ...
                     assets_shuffled.(assetClass)(jj).orientation;
                 assets_shuffled.(assetClass)(jj).motion.slope = ...
                     assets_shuffled.(assetClass)(jj).slope;
             end
        end
        for ii = 1:length(assets.(assetClass))
            if ~isfield(assets.(assetClass)(ii), 'geometry') 
                fprintf('No geometry information found in %s \n', ...
                    assets.(assetClass)(ii));
                break;
            end
            [~,n] = size(assets.(assetClass)(ii).geometry(1).position);
            position = cell(n, 1);
            rotationY = cell(n, 1); % rotationY is RotY
            slope = cell(n, 1); % Slope is RotZ
            motionPos = cell(n, 1);
            motionRotY = cell(n, 1); % rotationY is RotY
            motioinSlope = cell(n, 1); % Slope is RotZ
            for gg = 1:n
                position{gg} = assets_shuffled.(assetClass)(index).pos;
                rotationY{gg} = ...
                    assets_shuffled.(assetClass)(index).orientation - 90;
                slope{gg} = assets_shuffled.(assetClass)(index).slope;
                if isempty(slope{gg}), slope{gg} = 0; end
                motionPos{gg} = ...
                    assets_shuffled.(assetClass)(index).motion.pos;
                motionRotY{gg} = assets_shuffled.(...
                    assetClass)(index).motion.orientation - 90;
                motioinSlope{gg} = ...
                    assets_shuffled.(assetClass)(index).motion.slope;
                if isempty(motioinSlope{gg}), motioinSlope{gg} = 0; end
                index = index + 1;
            end
            % Add translation to the asset
            assets_updated.(assetClass)(ii).geometry = piAssetTranslate(...
                assets.(assetClass)(ii).geometry, position, ...
                'instancesNum', n);

            assets_updated.(assetClass)(ii).geometry = piAssetRotate(...
                assets_updated.(assetClass)(ii).geometry, ...
                'Y', rotationY, 'Z', slope, 'instancesNum', n);
            % Add Motion
            assets_updated.(assetClass)(ii).geometry = piAssetMotionAdd(...
                assets_updated.(assetClass)(ii).geometry, ...
                'translation', motionPos, 'Y', motionRotY, ...
                'Z', motioinSlope, 'instancesNum', n);
        end
    end
    assetsPosList{1} = assets_updated;
end
