classdef recipe < matlab.mixin.Copyable
% Contains essential information for rendering the PBRT file
%
%
% TL Scien Stanford, 2017

% PROGRAMMING TODO
%
%  Perhaps this class should be piRecipe.m
%
%  I think we should align the words here with the terms in PBRT.  So, for
%  example, integrator should be SurfaceIntegrator.  Then we should have the
%  permissible list of terms included.  Again, for SurfaceIntegrator in V2 these
%  appear to be described in http://www.pbrt.org/fileformat.html

%

    properties (GetAccess=public, SetAccess=public)
        % Can be set by user
        %
        % These are all structs that contain the parameters necessary
        % for piWrite to convert the structs to text output in the
        % scene.pbrt file.
        
        camera;      % Struct of camera parameters, such as lens file
        sampler;     % Sampling algorithm.  Only a few are allowed
        film;        % Equivalent to ISET sensor
        filter;      % Usually pixel filter
        integrator;  % Usually SurfaceIntegrator
        renderer;    %
        lookAt;      % from/to/up struct
        world;       % A cell array with all the WorldBegin/End contents
        inputFile;   % Original input file
        outputFile;  % Where outputFile = piWrite(recipe);
        
    end
    
    properties (Dependent)
    end
    
    methods
        % Constructor
        function obj = recipe(varargin)
            % Who knows what we will in the future.
        end
        function val = get(obj,varargin)
            % Returns derived parameters of the recipe that require some
            % computation
            val = recipeGet(obj,varargin{:});
        end
        
    end
    
end