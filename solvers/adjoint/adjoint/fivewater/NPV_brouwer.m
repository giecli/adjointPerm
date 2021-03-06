function [obj] = NPV_brouwer(G, S, W, rock, fluid, simRes, schedule, controls, varargin)
% simpleNPV - simple net-present-value function - no discount factor with
% barrier function
%
% SYNOPSIS:
%   obj = (G, S, W, rock, fluid, simRes, schedule, controls, varargin)
%
% DESCRIPTION:
%   Computes value of objective function for given simulation, and partial
%   derivatives of variables if varargin > 6
% PARAMETERS:
%   simRes      -
%
% RETURNS:
%   obj         - structure with fields
%        val    - value of objective function
%        
%   
%
%
% SEE ALSO:
%  
opt     = struct('OilPrice',                125, ...
                 'WaterProductionCost',     10,  ...
                 'WaterInjectionCost',      0,  ...
                 'RelativeDiscountFactor',  0);
opt     = merge_options(opt, varargin{:});
ro      = opt.OilPrice/0.1590;
rw      = opt.WaterProductionCost/0.1590;
ri      = opt.WaterInjectionCost/0.1590;
d       = opt.RelativeDiscountFactor;
%-----------------------------------------------

computePartials  = (nargin > 6);
numSteps = numel(simRes);
val      = 0;
partials = repmat( struct('v', [], 'p', [], 'pi', [], 's', [], 'u', []), [numSteps 1] );
totTime  = max( [simRes.timeInterval] );

% % barrier parameter
% t = t_value;
% 
% % maximum total water injection
% Ibound = TotMaxInj;

for step = 2 : numSteps
    resSol  = simRes(step).resSol;
    wellSol = simRes(step).wellSol;
    int     = simRes(step).timeInterval;
    dt      = int(2) - int(1);
    dFac    = (1+d)^(-int(2)/totTime);
    
    [wellRates, rateSigns] = getRates(W, wellSol);
    wellCells = vertcat( W.cells );
    wellSats  = resSol.sw( wellCells ); 
    %f_o       = 1 - fracFlow(wellSats, fluid);  % fractional flow oil
    f_w       = fluid.fw( wellSats );
    f_o       = 1 - f_w;
    injInx    = (rateSigns > 0);
    prodInx   = (rateSigns < 0);
    
%     twPrd     = -sum( wellRates(prodInx) .* f_w(prodInx) );
%     barrier   = (1/t)*log(Ibound - twPrd); 

%     if ~isreal(barrier)
%         val = -inf;
%     else
%         val   = val + dt*dFac*(  - sum(  wellRates(injInx)                )*ri ...
%                                  - sum( -wellRates(prodInx).*f_w(prodInx) )*rw ...
%                                  + sum( -wellRates(prodInx).*f_o(prodInx) )*ro );
%     end
    
    val   = val + dt*dFac*(  - sum(  wellRates(injInx)                )*ri ...
                                 - sum( -wellRates(prodInx).*f_w(prodInx) )*rw ...
                                 + sum( -wellRates(prodInx).*f_o(prodInx) )*ro );
         
    
    if computePartials
        numCF    = size(G.cellFaces, 1);
        numC     = G.cells.num;
        numF     = G.faces.num;
        numU     = numel(controls.well);
        
        partials(step).v   = zeros(1, numCF);
        partials(step).p   = zeros(1, numC);
        partials(step).pi  = zeros(1, numF);
        
        partials(step).q_w =  - dt*dFac*ri*injInx' ...
                              + dt*dFac*rw*( prodInx.*f_w )' ...
                              - dt*dFac*ro*( prodInx.*f_o )';
%         % due to the barrier function
%         partials(step).q_w = partials(step).q_w - (1/t) * (1/(Ibound - twPrd)) * ( prodInx.*f_w )';
        
        
        Df_w     = fluid.Dfw( wellSats );
        Df_o     = - Df_w;
        %Df_o  = - DFracFlow(wellSats, fluid);
        ds    = zeros(1, numC);
        ds( wellCells(prodInx) )  =  dt*dFac*rw*( wellRates(prodInx).*Df_w(prodInx) )' ...
                                    -dt*dFac*ro*( wellRates(prodInx).*Df_o(prodInx) )';
        
        partials(step).s   = ds;
        
        partials(step).u  = zeros(1, numU);
        
         % Second order derivatives:
        D2f_w = fluid.D2fw( wellSats );
        D2f_o = -D2f_w;
        
        d2s = zeros(numC, 1);
        d2s( wellCells(prodInx) )  =  dt*dFac*rw*( wellRates(prodInx).*D2f_w(prodInx) )' ...
                                     -dt*dFac*ro*( wellRates(prodInx).*D2f_o(prodInx) )'; 
        partials(step).s2   = spdiags(d2s, 0, numC, numC);
        % --------------------
        %IX = sparse( wellCells(prodInx), (1:nnz(prodInx))', 1, G.cells.num, nnz(prodInx));
        % ds' = IX * (dt*dFac*rw*prodRates*(IX' * Df_w(s)) + ...
        %dssl = dt*dFac*rw*( wellRates(prodInx).*D2f_w(prodInx) ) ...
        %      -dt*dFac*ro*( wellRates(prodInx).*D2f_o(prodInx) ); 
        %partss = IX*spdiags(dssl, 0,  nnz(prodInx), nnz(prodInx))*IX';
        
        partials(step).qs   = dt * dFac * sparse(wellCells(prodInx), find(prodInx), rw*Df_w(prodInx)-ro*Df_o(prodInx), ...
                                             numC, length(prodInx));
    end
end

obj.val = val;
if computePartials, obj.partials = partials; end


function [f_w] = fracFlow(s, fluid)
% Derivative of fractional flow function of the form
%
%            s??/??w              s??                ??w
%    f(s) = ---------------- = ------------ ,  mr=---
%            s??/??w+(1-s)??/??o    s??+mr*(1-s)??      ??o
%    

mr   = fluid.muw/fluid.muo; % !!!!!!!!!!!!!!!!!
f_w  = ( s.^2 ) ./ (s.^2 + mr*(1-s).^2);
return


function [df] = DFracFlow(s, fluid)
% Derivative of fractional flow function of the form
%
%            s??/??w              s??                ??w
%    f(s) = ---------------- = ------------ ,  mr=---
%            s??/??w+(1-s)??/??o    s??+mr*(1-s)??      ??o
%
%
%            2 mr*s(1-s)
%   df(s) = ---------------
%           (s??+mr*(1-s)??)??        

mr  = fluid.muw/fluid.muo; % !!!!!!!!!!!!!!!!!
df  = ( (2*mr) * s .* (1-s) ) ./ ( (s.^2 + mr*(1-s).^2).^2 );
return
