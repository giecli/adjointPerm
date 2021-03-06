function [adjRes] = solveAdjointPressureSystem(G, S, W, rock, fluid, simRes, adjRes, obj, varargin)

% Find current time step (search for empty slots in adjRes)
% NOTE: actually curent time step +1
curStep = find( cellfun(@(x)~isempty(x), {adjRes.timeInterval}), 1, 'first');
dt      = simRes(curStep).timeInterval * [-1 1]';

% Generate RHS, that is f-part (rest is zero)
PV      = G.cells.volumes.*rock.poro;
invPV   = 1./PV;
%f_w     = fluid.krw(simRes(curStep).resSol) ./ fluid.Lt(simRes(curStep).resSol); % fractinal flow, f(s^n)
f_w     = fluid.fw( simRes(curStep).resSol);
l_s     = adjRes(curStep).resSol.s;        % lam_s^n
% Flux-matrix: A.i, A.j, A.qMinus
[A, qPluss, signQ] = generateUpstreamTransportMatrix(G, S, W, simRes(curStep).resSol, ...
                                        simRes(curStep).wellSol, 'VectorOutput', true);

dQPluss =  double( signQ > 0 );
dQMinus = -double( signQ < 0 );

f_bc    = -obj.partials(curStep).v';
cellNo  = rldecode(1:G.cells.num, double(G.cells.numFaces), 2) .';
S.C     = sparse(1:numel(cellNo), cellNo, 1);
f_bc    = f_bc - dt*( f_w(A.j).*( S.C*(invPV.*l_s) ) ) ...
               + dt*( S.C*( (-f_w.*dQMinus + dQPluss).*( invPV.*l_s ) ) );

% Set f and h in W(i).S.RHS equal DJ/Dp_w and zero. Leave naumannFaces and dirichletFaces as is 
inx = 0;
for wellNr = 1 : numel(W)
    numCells = length( W(wellNr).cells );
    W(wellNr).S.RHS.f = obj.partials(curStep).q_w( inx+1 : inx+numCells )';
    W(wellNr).S.RHS.h = zeros( size(W(wellNr).S.RHS.h) );  %change by EKA
%     W(wellNr).S.RHS.h = obj.partials(curStep).p( W(wellNr).cells );  % if obj.func. depends on BHP
    inx = inx + numCells;
end

% Solve linear system based on s^{n-1}
b   = computeAdjointRHS(G, W, f_bc);

% % Obj.func. depends on pressure at all grid blocks
% b{2} =  -obj.partials(curStep).p;

if strcmp(S.type, 'hybrid')
   solver = 'hybrid';
else
   solver = 'mixed';
end

[resSol, wellSol] = solveIncompFlow(simRes(curStep-1).resSol, [], G, ...
                                    S, fluid, 'wells', W, 'rhs', b,  ...
                                    'Solver', solver);

% Update adjRes !!! Note minuses in front of pressure and wellrates in
% forward system, but not in adjoint, thus set minus here  
adjRes(curStep).resSol.cellFlux     = resSol.cellFlux;
adjRes(curStep).resSol.cellPressure = - resSol.cellPressure;           % !!!minus
adjRes(curStep).resSol.facePressure = resSol.facePressure;
adjRes(curStep).wellSol             = wellSol;
for k = 1 : numel(adjRes(curStep).wellSol)
    adjRes(curStep).wellSol(k).flux = - adjRes(curStep).wellSol(k).flux;     % !!!minus
end
end
