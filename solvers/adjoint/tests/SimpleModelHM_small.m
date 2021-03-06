% SimpleModelHM_small
% a 4 x 4 reservoir for history matching
%
% whether or not to show output
verbose      = false;
verboseLevel = 0;

nx = 5; ny = 5; nz = 1;
G  = cartGrid([nx ny nz]);
G  = computeGeometry(G);

% define K -> K/m, where m is permeability multiplier
% let K = one

m     = ones(nx,ny);
% Kreal = ones(nx,ny);
Kreal = [ 1 1 1 1 1; ...
          1 1 1 1 1; ...
          1 1 2 2 2; ...
          1 1 2 2 2; ...
          1 1 2 2 2 ];
m     = reshape(m, [1,G.cells.num]);
Kreal = reshape(Kreal, [1,G.cells.num]);
% K     = m ./ Kreal;
K     = Kreal ./ m;

save Kreal.mat Kreal;
save Kmodel.mat K;

% load permSmall;
% perm = reshape(permSmall', [1,G.cells.num]);
perm = reshape(K, [1,G.cells.num]);
rock.perm = perm'*100*milli*darcy;
rock.poro = repmat(0.3, [G.cells.num, 1]);

fluid      = initCoreyFluid('mu', [1 5], 'sr', [0 0] );
resSolInit = initResSol(G, 0.0);

S = computeMimeticIP(G, rock, 'Type', 'comp_hybrid', 'Verbose', verbose, 'InnerProduct', 'ip_tpf');

% Choose objective function
objectiveFunction = str2func('ratesMatch');


totRate = 1/day;

% Introduce wells
radius = .1;

Wref = addWell(G, rock,[], nx*floor(ny/2) + ceil(nx/2)     , 'Type', 'rate' ,'Val',  totRate   , 'Radius', radius, 'Name', 'i1');
Wref = addWell(G, rock, Wref, 1         , 'Type', 'rate', 'Val',   -totRate/4  , 'Radius', radius, 'Name', 'p1');
Wref = addWell(G, rock, Wref, nx        , 'Type', 'rate', 'Val',   -totRate/4   , 'Radius', radius, 'Name', 'p2');
Wref = addWell(G, rock, Wref, nx*ny-nx+1, 'Type', 'rate', 'Val',   -totRate/4   , 'Radius', radius, 'Name', 'p3');
Wref = addWell(G, rock, Wref, nx*ny     , 'Type', 'rate', 'Val',   -totRate/4   , 'Radius', radius, 'Name', 'p4');

Wref = assembleWellSystem(G, Wref, 'Type', 'comp_hybrid');

totVol   = sum(G.cells.volumes.*rock.poro);
schedule = initSchedule(Wref, 'NumSteps', 1, 'TotalTime', 360*day, 'Verbose', verbose);

simRes_refSmall = runSchedule(resSolInit, G, S, Wref, rock, fluid, schedule, ...
                             'VerboseLevel', verboseLevel);

save simResSmallRef.mat simRes_refSmall;
                          
return;                              
                              
 