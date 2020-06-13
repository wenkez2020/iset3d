function val = recipeGet(thisR, param, varargin)
% Derive parameters from the recipe class
%
% Syntax:
%     val = recipeGet(thisR, param, ...)
%
% Inputs:
%     thisR - a recipe object
%     param - a parameter (string)
%
% Returns
%     val - derived parameter
%
% Parameters
%
%   % Data management
%     'input file'      - full path to original scene pbrt file
%     'input base name' - just base name of input file
%     'input dir'       - Directory of the input file
%     'output file'     - full path to scene pbrt file in working directory
%     'output base name' - just the base name of the output file
%     'output dir'       - Directory of the output file
%     'rendered file'    - dat-file where piRender creates the radiance
%     'rendered dir'     - directory with rendered data 
%     'working directory' - directory mounted by docker image
%
%   % Camera and scene
%     'object distance'  - The magnitude ||(from - to)|| of the difference
%                          between from and to.  Units are from the scene,
%                          typically in meters. 
%     'object direction' - Unit length vector of from and to
%     'look at'          - Struct with four components
%        'from'           - Camera location
%        'to'             - Camera points at
%        'up'             - Direction that is 'up'
%        'from to'        - vector difference (from - to)
%     'optics type'      -
%     'lens file'        - Name of lens file in data/lens
%     'focal distance'   - See autofocus calculation (mm)
%     'pupil diameter'   - In millimeters
%     'fov'              - (Field of view) only used if 'optics type' is
%                          'pinhole' 
%
%    % Light field camera
%     'n microlens'      - 2-vector, row,col (alias 'n pinholes')
%     'n subpixels'      - 2 vector, row,col
%
%    % Rendering
%      'integrator'
%      'n bounces'
%
%    %  Asset information
%       'assets'      - Not sure I am doing this right
%       'asset names' - The names in groupobjs.name
%
% BW, ISETBIO Team, 2017

% Examples
%{
  val = thisR.get('working directory');
  val = thisR.get('object distance');
  val = thisR.get('focal distance');
  val = thisR.get('camera type');
  val = thisR.get('lens file');
%}

% Programming todo
%

%% Parameters

if isequal(param,'help')
    doc('recipe.recipeGet');
    return;
end

p = inputParser;
vFunc = @(x)(isequal(class(x),'recipe'));
p.addRequired('thisR',vFunc);
p.addRequired('param',@ischar);
% p.addOptional('material', [], @iscell);

p.parse(thisR,param);

switch ieParamFormat(param)  % lower case, no spaces
    
    % Data management
    case 'inputfile'
        val = thisR.inputFile;
    case 'inputdir'
        val = fileparts(thisR.get('input file'));
    case {'inputbasename'}
        name = thisR.inputFile;
        [~,val] = fileparts(name);        
    case 'outputfile'
        % This file location defines the working directory that docker
        % mounts to run.
        val = thisR.outputFile;
    case 'outputdir'
        val = fileparts(thisR.get('output file'));
    case {'outputbasename'}
        name = thisR.outputFile;
        [~,val] = fileparts(name);
    case 'renderedfile'
        val = fileparts(thisR.get('rendered file'));
    case {'rendereddir'}
        name = thisR.outputFile;
        [~,val] = fileparts(name);
    case {'materialsfile'}        
        n = thisR.get('input basename');
        p = thisR.get('input dir');
        fname_materials = sprintf('%s_materials.pbrt',n);
        val = fullfile(p,fname_materials);
               
    case {'workingdirectory','dockerdirectory'}
        % Docker mounts this directory.  Everything is copied into it for
        % the piRender command to run.
        outputFile = thisR.get('output file');
        val = fileparts(outputFile);
    
        % Graphics related
    case {'exporter'}
        val = thisR.exporter;
        
        % Scene and camera direction
    case 'objectdistance'
        diff = thisR.lookAt.from - thisR.lookAt.to;
        val = sqrt(sum(diff.^2));
    case 'objectdirection'
        % A unit vector in the lookAt direction
        val = thisR.lookAt.from - thisR.lookAt.to;
        val = val/norm(val);
    case 'lookat'
        val = thisR.lookAt;
    case 'from'
        val = thisR.lookAt.from;
    case 'to'
        val = thisR.lookAt.to;
    case 'up'
        val = thisR.lookAt.up;
    case 'fromto'
        % Vector between from minus to
        val = thisR.lookAt.from - thisR.lookAt.to;
      case 'tofrom'
        % Vector between from minus to
        val = thisR.lookAt.to - thisR.lookAt.from;
       
    case {'cameratype'}
    case {'exposuretime','cameraexposure'}
        try
            val = thisR.camera.shutterclose.value - thisR.camera.shutteropen.value;
        catch
            val = 1;  % 1 sec is the default.  Too long.
        end
        
        % Lens and optics
    case 'opticstype'
        % perspective means pinhole.  Maybe we should rename.
        % realisticDiffraction means lens.  Not sure of all the possibilities
        % yet.
        val = thisR.camera.subtype;
        if isequal(val,'perspective'), val = 'pinhole';
        elseif isequal(val,'environment'), val = 'environment';
        elseif ismember(val,{'realisticDiffraction','realisticEye','realistic','omni'})
            val = 'lens';
        end
    case 'lensfile'
        % See if there is a lens file and assign it.
        subType = thisR.camera.subtype;
        switch(lower(subType))
            case 'pinhole'
                val = 'pinhole';
            case 'perspective'
                val = 'pinhole (perspective)';
            otherwise
                % realisticeye and realisticDiffraction both work here.
                % Need to test 'omni'               
                try
                    [~,name,ext] = fileparts(thisR.camera.lensfile.value);
                    val = [name,ext];
                catch
                    error('Unknown lens file %s\n',subType);
                end
                
        end
    case {'focusdistance','focaldistance'}
        % recipe.get('focal distance')  (m)
        %
        % Distance in object space to the focal plane. If a lens type,
        % we check whether the lens can bring this distance into focus
        % on the film plane.
        opticsType = thisR.get('optics type');
        switch opticsType
            case {'pinhole','perspective'}
                % Everything is in focus for a pinhole camera
                val = thisR.camera.focaldistance.value;
                warning('Pinhole optics.  No real focal distance');
            case {'environment'}
                % Everything is in focus for the panorama
                disp('Panorama rendering. No focal distance');
                val = NaN;
            case 'lens'
                % Focal distance given the object distance and the lens file
                % [p,flname,ext] = fileparts(thisR.camera.lensfile.value);
                % focalLength = load(fullfile(p,[flname,'.FL.mat']));  % Millimeters
                val = thisR.camera.focusdistance.value;
                lensFile = thisR.get('lens file');
                
                % Not required, but aiming to be helpful.  Convert the
                % distance to the focal plane into millimeters and see
                % whether the lens can adjust the film distance so
                % that the plane is in focus.
                if lensFocus(lensFile,1e+3*val) < 0
                    warning('%s lens cannot focus at this distance.', lensFile);
                end
                
            otherwise
                error('Unknown camera type %s\n',opticsType);
        end
    case {'fov','fieldofview'}
        % recipe.get('fov') - degrees
        % 
        % Correct for pinhole, but just an approximation for lens
        % camera.
        filmDiag      = thisR.get('film diagonal'); 
        if isequal(thisR.get('optics type'),'pinhole')
            if isfield(thisR.camera,'fov')
                val = thisR.camera.fov.value;
                filmratio = thisR.film.xresolution.value/thisR.film.yresolution.value;
                if filmratio > 1
                    val = 2*atand(tand(val/2)*filmratio); 
                end
            else
                val = atand(filmDiag/2/thisR.camera.filmdistance.value);
            end
        else
            % Coarse estimate of the diagonal FOV (degrees) for the
            % lens case. Film diagonal size and distance from the film
            % to the back of the lens.
            focusDistance = thisR.get('focus distance');    % meters
            lensFile      = thisR.get('lens file');
            filmDistance  = lensFocus(lensFile,1e+3*focusDistance); % mm
            val           = atand(filmDiag/2/filmDistance);
        end
    case 'pupildiameter'
        % Default is millimeters
        val = 0;  % Pinhole
        if strcmp(thisR.camera.subtype,'realisticEye')
            val = thisR.camera.pupilDiameter.value;
        end
    case 'chromaticaberration'
        % thisR.get('chromatic aberration')
        % True or false (on or off)
        val = thisR.camera.chromaticAberrationEnabled.value;
        if isequal(val,'true'), val = true; else, val = false; end
    case 'numcabands'
        % thisR.get('num ca bands')
        try
            val = thisR.integrator.numCABands.value;
        catch
            val = 0;
        end

        % Light field camera parameters
    case {'nmicrolens','npinholes'}
        % How many microlens (pinholes)
        val(2) = thisR.camera.num_pinholes_w.value;
        val(1) = thisR.camera.num_pinholes_h.value;
    case 'nsubpixels'
        % How many film pixels behind each microlens/pinhole
        val(2) = thisR.camera.subpixels_w;
        val(1) = thisR.camera.subpixels_h;
        
        % Film
    case 'filmresolution'
        try
            val = [thisR.film.xresolution.value,thisR.film.yresolution.value];
        catch
            warning('Film resolution not specified');
            val = [];
        end
        
    case 'filmxresolution'
        % An integer
        val = thisR.film.xresolution.value;
    case 'filmyresolution'
        % An integer
        val = [thisR.film.yresolution.value];
    case 'aperturediameter'
        % Needs to be checked.
        if isfield(thisR.camera, 'aperturediameter') ||...
            isfield(thisR.camera, 'aperture_diameter')
                val = thisR.camera.aperturediameter.value;
        else
            val = nan;
        end
        
    case {'filmdiagonal','filmdiag'}
        % recipe.get('film diagonal');  in mm
        if isfield(thisR.film,'diagonal')
            val = thisR.film.diagonal.value;
        end
  
    case 'filmsubtype'
        % What are the legitimate options?
        if isfield(thisR.film,'subtype')
            val = thisR.film.subtype;
        end
        
    case {'raysperpixel'}
        if isfield(thisR.sampler,'pixelsamples')
            val = thisR.sampler.pixelsamples.value;
        end
        
    case {'cropwindow'}
        if(isfield(thisR.film,'cropwindow'))
            val = thisR.film.cropwindow.value;
        else
            val = [0 1 0 1];
        end
        
        % Rendering related
    case{'maxdepth','bounces','nbounces'}
        if isfield(thisR.integrator,'maxdepth')
            val = thisR.integrator.maxdepth.value;
        end
        
    case{'integrator'}
        if isfield(thisR.integrator,'subtype')
            val = thisR.integrator.subtype;
        end
        
    case{'camerabody'}
        % thisR.get('camera body');
        val.camera = thisR.camera;
        val.film   = thisR.film;
        val.filter = thisR.filter;
        
    case{'material'}
        if isfield(thisR.materials, 'list')
            val = thisR.materials.list;
        else
            val = {};
        end
    case{'texture'}
        if isfield(thisR.textures, 'list')
            val = thisR.textures.list;
        else
            val = {};
        end
    case{'light'}
        val = thisR.light;
        
    % Assets - more work needed here.
    case {'assetroot'}
        % The root of all assets
        val = thisR.assets;
        
    case {'groupnames'}
        % Cell array (2D) of the groupobj names
        % val{level}{idx}
        val = piAssetNames(thisR);
    case {'groupindex'}
        % thisR.get('groupindex',groupName)
        % gnames = thisR.get('group names')
        %
        % gnames{idx(1)}{dx(2)}
        if isempty(varargin), error('group name required'); end
        val = piAssetNames(thisR,'group find',varargin{1});
    case {'groupobj'}
        % groupobj = thisR.get('groupobj',idx);
        % idx from group index
        %
        % idx = piAssetNames(thisR,'group find','figure_3m');
        thisG = thisR.assets;
        % Work through the levels
        for level = 1:idx(1)
            thisG = thisG.groupobjs;
        end
        % Select the group
        val = thisG(idx(2));
        
    case {'childrennames'}
        % cnames = thisR.get('children names')
        % Cell array (2D) of the children names
        %
        [~,val] = piAssetNames(thisR);
        
    case {'childrenindex'}
        % idx = thisR.get('children index',childName)
        % cnames = thisR.get('children names')
        %
        % These are 3-vectors (level, group, idx)
        %
        % cnames{idx(1)}{dx(2)}
        %
        if isempty(varargin), error('child name required'); end
        val = piAssetNames(thisR,'children find',varargin{1});
    case {'child'}
        % child = thisR.get('child',idx); 
        %
        % idx from child index is a 3 vector. There can be multiple
        % groupobjs at this level and we need to know which one has the
        % specific child.  So we need
        %
        %   [level, groupidx, childidx]
        %
        % idx = piAssetNames(thisR,'children find','3_1_Moon Light');
        thisG = thisR.assets;
        for level = 1:idx(1)
            % Work through the levels
            thisG = thisG.groupobjs;
        end
        % Find the group and child
        val = thisG(idx(2)).children(idx(3));
        
    otherwise
        error('Unknown parameter %s\n',param);
end

end