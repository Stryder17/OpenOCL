classdef CasadiNLPSolver < NLPSolver
  
  properties (Access = private)
    nlpData
    options
  end
  
  methods
    
    function self = CasadiNLPSolver(nlp,options)
      
      self.nlp = nlp;
      self.options = options;
      self.nlpData = self.construct(nlp,options);
    end
    
    function nlpData = construct(self,nlp,options)
      
      constructTotalTic = tic;
      
      % create variables as casadi symbolics
      if options.nlp_casadi_mx
        vars = casadi.MX.sym('v', nlp.nv,1);
      else
        vars = casadi.SX.sym('v', nlp.nv,1);
      end

      % call nlp function
      [costs,constraints,constraints_LB,constraints_UB,~] = nlp.nlpFun.evaluate(vars);
      
      % get struct with nlp for casadi
      casadiNLP = struct;
      casadiNLP.x = vars;
      casadiNLP.f = costs;
      casadiNLP.g = constraints;
      casadiNLP.p = [];

      nlpData = struct;
      nlpData.casadiNLP = casadiNLP;
      nlpData.constraints_LB = constraints_LB;
      nlpData.constraints_UB = constraints_UB;
      self.timeMeasures.constructTotal = toc(constructTotalTic);
    end
    
    function [outVars,times,objective,constraints] = solve(self,initialGuess)
      % solve(initialGuess)
      
      solveTotalTic = tic;
      
      % interpolate initial guess
      if self.options.nlp.auto_interpolation
        initialGuess.interpolateIntegrator();
      end
      
      v0 = initialGuess.value;
      
      [lbv,ubv] = self.nlp.getNlpBounds();
 
      opts = self.options.nlp.casadi;
      if isfield(self.options.nlp,self.options.nlp.solver)
        opts.(self.options.nlp.solver) = self.options.nlp.(self.options.nlp.solver);
      end
      
      constructSolverTic = tic;
      casadiSolver = casadi.nlpsol('my_solver', self.options.nlp.solver,... 
                                   self.nlpData.casadiNLP, opts);
      constructSolverTime = toc(constructSolverTic);
      
      args = struct;
      args.lbg = self.nlpData.constraints_LB;
      args.ubg = self.nlpData.constraints_UB;
      args.p = [];
      args.lbx = lbv;
      args.ubx = ubv;
      args.x0 = v0;
      
      % execute solver
      solveCasadiTic = tic;
      sol = casadiSolver.call(args);
      solveCasadiTime = toc(solveCasadiTic);
      
      if strcmp(self.options.nlp.solver,'ipopt') && strcmp(casadiSolver.stats().return_status,'NonIpopt_Exception_Thrown')
        error('Solver was interrupted by user.');
      end
      
      solution = sol.x.full();
      
      nlpFunEvalTic = tic;
      if nargout > 1
        [objective,constraints,~,~,times] = self.nlp.nlpFun.evaluate(solution);
      end
      nlpFunEvalTime = toc(nlpFunEvalTic);
      
      times = Variable.createNumeric(self.nlp.timesStruct,full(times));

      initialGuess.set(solution);
      outVars = initialGuess;
      
      self.timeMeasures.solveTotal      = toc(solveTotalTic);
      self.timeMeasures.solveCasadi     = solveCasadiTime;
      self.timeMeasures.constructSolver = constructSolverTime;
      self.timeMeasures.nlpFunEval      = nlpFunEvalTime;
      
      oclWarningNotice()
    end
  end
  
end
