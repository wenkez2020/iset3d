function piTextureSetBasis(thisR, textureIdx, wave, varargin)
% This is a temporary function to add basis function
% Currently only allows basis function stored in .spd file
%
%
%
%% Parse 
varargin = ieParamFormat(varargin);
p = inputParser;

p.addRequired('thisR');
p.addRequired('textureIdx', @isnumeric);
p.addRequired('wave');
p.addParameter('basisfunctions',zeros(3, numel(wave)));

p.parse(thisR, textureIdx, wave,varargin{:});
thisR = p.Results.thisR;
textureIdx = p.Results.textureIdx;
wave = p.Results.wave;
basisFunctions = p.Results.basisfunctions;
%%

thisR.textures.list{textureIdx}.spectrumbasisone = ...
                            'spds/lights/basisone.spd';
thisR.textures.list{textureIdx}.spectrumbasistwo = ...
                            'spds/lights/basistwo.spd';           
thisR.textures.list{textureIdx}.spectrumbasisthree = ...
                            'spds/lights/basisthree.spd';     

%%
%{
txtLines = thisR.materials.txtLines;
for jj = 1:size(txtLines)
    if ~isempty(txtLines(jj))
        if piContains(txtLines(jj),'MakeNamedMaterial')
            txtLines{jj}=[];
        end
    end
end
textureLines = txtLines(~cellfun('isempty',txtLines));

thisTexture = textureLines{textureIdx};
thisTexturesplt = split(thisTexture, '"');
targetTextureName = thisTexturesplt{2};

% Loop through all lines
newTxtLines = thisR.materials.txtLines;
for jj = 1:numel(newTxtLines)
    if ~isempty(newTxtLines(jj))
        if piContains(newTxtLines(jj), strcat("Texture ", '"',targetTextureName, '"'))
            basisLine = strcat(' "spectrum basisone"', ' "spds/lights/basisone.spd" ',...
                               ' "spectrum basistwo"', ' "spds/lights/basisTwo.spd" ',...
                               ' "spectrum basisthree"', ' "spds/lights/basisThree.spd" ');
            thisLine_tmp = split(newTxtLines{jj}, '"string filename"');
            newTxtLines{jj} = strcat(thisLine_tmp{1}, basisLine, ' "string filename" ',...
                                      thisLine_tmp{2});
        end
    end
end

thisR.materials.txtLines = newTxtLines;
%}
%% Write out new spd files

filenames = {'basisone', 'basistwo', 'basisthree'};
% basisFunctions = {basisOne, basisTwo, basisThree};

% Specify the save path to the three basis functions
outputDir = fileparts(thisR.outputFile);
lightSpdDir = fullfile(outputDir, 'spds', 'lights');
if ~exist(lightSpdDir, 'dir'), mkdir(lightSpdDir); end


if isnumeric(basisFunctions)
    % Assume the shape of the basisFunctions is nWave x 3
    loadedFunctions = basisFunctions;
   
elseif exist(basisFunctions, 'file') % basis functions are stored in a file
    loadedFunctions = ieReadSpectra(basisFunctions, wave);
else
    error('Unable to assign this set basis functions.');
end

for ii = 1:3
    thisBasis = loadedFunctions(:,ii);
    thisLightfile = fullfile(lightSpdDir,...
                    sprintf('%s.spd', filenames{ii}));
    fid = fopen(thisLightfile, 'w');
    for jj = 1: length(wave)
        fprintf(fid, '%d %d \n', wave(jj), thisBasis(jj));
    end
    fclose(fid);            
end
end