%% s_focusLensTable
%
% For each lens file, make a look-up table from dist (in mm) to focal length
% (mm). Then, whenever we use a particular file, and we have a distance from the
% camera to the 'lookat' value in the PBRT file, we can use this table to find
% the in-focus film distance. 
%
% First, we build the whole table, T, that has the different *.dat files in the
% data/lens directory as the rows and the distance to object as the columns. The
% entries are the focalDistance (all distances are millimeters, mm).
%
%   T(whichLens,dist) = focalDistance
%
% When the values are negative, we set the entry to NaN.
%
% We plot the focal distance vs. the object distance.  
%
% Finally, we write out file (lensFile.FL.mat) that contains the values 'dist'
% and focalDistance as parameters that can be used to interpolate for any
% distance in a scene.
%
%   focalLength = load(fullfile(p,[flname,'.FL.mat']));
%   focalDistance = interp1(focalLength.dist,focalLength.focalDistance,objDist);
%
% BW SCIEN Stanford, 2017

%%  All the lenses in the pbrt2ISET directory

lensDir = fullfile(piRootPath,'data','lens');

% wide, tessar, fisheye, dgauss, telephoto, 2el, 2EL
lensFiles = dir(fullfile(lensDir,'*.dat'));   

dist = logspace(0.1,4,30);

%% Calculate the focal distances

focalDistance = zeros(length(lensFiles),length(dist));

for ii=1:length(lensFiles)
    fname = fullfile(lensDir,lensFiles(ii).name);
    for jj=1:length(dist)
        focalDistance(ii,jj) = lensFocus(lensFiles(ii).name,dist(jj));
    end
end

%%  When the distance is too small, we can't get a good focus.

% In that case, the distance is negative
vcNewGraphWin;
focalDistance(focalDistance < 0) = NaN;
loglog(dist,focalDistance');
xlabel('Object distance (mm)'); ylabel('Focal length (mm)');
grid on

%%  Write out the focalLength data for each of the file types
allFocalDistances = focalDistance;
for ii=1:length(lensFiles)
    [p,n,~] = fileparts(lensFiles(ii).name);
    flFile = fullfile(lensDir,[n,'.FL.mat']);
    focalDistance = allFocalDistances(ii,:);
    save(flFile,'dist','focalDistance');
end

