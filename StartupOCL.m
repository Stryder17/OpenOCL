function StartupOCL(in)
  % StartupOCL(workingDirLocation)
  % StartupOCL(octaveClear)
  % Startup script for OpenOCL
  % Adds required directories to the path. Sets up a folder for the results
  % of tests and a folder for autogenerated code.
  % 
  % inputs:
  %   workingDirLocation - path to location where the working directory 
  %                        should be created.

  oclPath  = fileparts(which('StartupOCL'));

  if isempty(oclPath)
    error('Can not find OpenOCL. Add root directory of OpenOCL to the path.')
  end

  workingDirLocation = fullfile(oclPath,'..');
  octaveClear = false;

  if nargin == 1 && (islogical(in)||isnumeric(in))
    octaveClear = in;
  elseif nargin == 1 && ischar(in)
    workingDirLocation = in;
  elseif nargin == 1
    oclError('Invalid argument.')
  end

  % add current directory to path
  addpath(pwd);

  % create folders for tests and autogenerated code
  testDir     = fullfile(workingDirLocation,'OpenOCL_WorkingDir','test');
  exportDir   = fullfile(workingDirLocation,'OpenOCL_WorkingDir','export');
  [~,~] = mkdir(testDir);
  [~,~] = mkdir(exportDir);

  % set environment variables for directories
  setenv('OPENOCL_PATH', oclPath)
  setenv('OPENOCL_TEST', testDir)
  setenv('OPENOCL_EXPORT', exportDir)

  % setup directories
  addpath(oclPath)
  addpath(exportDir)
  addpath(fullfile(oclPath,'CasadiLibrary'))

  addpath(fullfile(oclPath,'Core'))
  addpath(fullfile(oclPath,'Core','Integrator'))
  addpath(fullfile(oclPath,'Core','Variables'))
  addpath(fullfile(oclPath,'Core','Variables','Variable'))
  addpath(fullfile(oclPath,'Core','utils'))

  addpath(fullfile(oclPath,'Examples'))
  addpath(fullfile(oclPath,'Examples','01VanDerPol'))
  addpath(fullfile(oclPath,'Examples','02BallAndBeam'))
  addpath(fullfile(oclPath,'Examples','03Pendulum'))
  addpath(fullfile(oclPath,'Examples','04RaceCar'))
  addpath(fullfile(oclPath,'Test'))


  % check if casadi is working
  try
    casadi.SX.sym('x');
  catch e
    if strcmp(e.identifier,'MATLAB:undefinedVarOrClass') || strcmp(e.identifier,'Octave:undefined-function')
      error('Casadi installation not found. Please setup casadi 3.3 or higher');
    else
      error('Casadi installation in the path found but does not work properly. Try restarting Matlab.');
    end
  end

  % remove properties function in Variable.m for Octave which gives a
  % parse error
  if isOctave()
    variableDir = fullfile(oclPath,'Core','Variables','Variable');
    %rmpath(variableDir);
    
    vFilePath = fullfile(exportDir, 'Variable','Variable.m');
    if ~exist(vFilePath,'file') || octaveClear
      delete(fullfile(exportDir, 'Variable','V*.m'))
      status = copyfile(variableDir,exportDir);
      assert(status, 'Could not copy Variables folder');
    end
      
    vFileText = fileread(vFilePath);
    searchPattern = 'function n = properties(self)';
    replacePattern = 'function n = ppp(self)';
    pIndex = strfind(vFileText,searchPattern);
    
    if ~isempty(pIndex)
      assert(length(pIndex)==1, ['Found multiple occurences of properties ',...
                                 'function in Variable.m; Please reinstall ',...
                                 'OpenOCL.'])
      newText = strrep(vFileText,searchPattern,replacePattern);
      fid=fopen(vFilePath,'w');
      fwrite(fid, newText);
      fclose(fid);
    end
    addpath(fullfile(exportDir,'Variable'));
  end
