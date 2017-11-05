%% s_piReadRenderLens
%
% Rendering takes longer through a lens as the size of the aperture grows.
% The pinhole case is always the fastest, of course.
%
% See Temporary.m for a thisROrig that runs correctly.  Delete that when this
% runs correctly.
%
% See also
%  s_piReadRender, s_piReadRenderLF
%  
%
% BW SCIEN Team, 2017

%% Initialize ISET and Docker

ieInit;
if ~piDockerExists, piDockerConfig; end

%% Specify the pbrt scene file and its dependencies

% We organize the pbrt files with its includes (textures, brdfs, spds, geometry)
% in a single directory. 
fname = fullfile(piRootPath,'data','teapot-area','teapot-area-light.pbrt');
if ~exist(fname,'file'), error('File not found'); end

% Read the main scene pbrt file.  Return it as a recipe
thisR = piRead(fname);

%% Modify the recipe, thisR, to adjust the rendering

thisR.set('camera','realistic');
thisR.set('aperture',4);  % The number of rays should go up with the aperture 
thisR.set('film resolution',512);
thisR.set('rays per pixel',384);

% We need to move the camera far enough away so we get a decent focus.
objDist = thisR.get('object distance');
thisR.set('object distance',10*objDist);
thisR.set('autofocus',true);

%% Set up Docker 

% Docker will mount the volume specified by the working directory
workingDirectory = fullfile(piRootPath,'local');

% We copy the pbrt scene directory to the working directory
[p,n,e] = fileparts(fname); 
copyfile(p,workingDirectory);

% Now write out the edited pbrt scene file, based on thisR, to the working
% directory.
oname = fullfile(workingDirectory,[n,e]);
piWrite(thisR, oname, 'overwrite', true);

%% Render with the Docker container

oi = piRender(oname,'meanilluminance',10);

% Show it in ISET
vcAddObject(oi); oiWindow; oiSet(oi,'gamma',0.5);   

%%