function W = addWell(G, rock, W, cellInx, varargin)
%Insert a well into the simulation model.
%
% SYNOPSIS:
%   W = addWell(G, rock, W, cellInx)
%   W = addWell(G, rock, W, cellInx, 'pn', pv, ...)
%
% PARAMETERS:
%   G       - Grid data structure.
%
%   rock    - Rock data structure.  Must contain valid field 'perm'.
%
%   W       - Well structure or empty if no other wells exist.
%             Updated upon return.
%
%   cellInx - Perforated well cells (vector of cell indices).
%
%   'pn'/pv - List of 'key'/value pairs defining optional parameters.  The
%             supported options are:
%               - InnerProduct -- The inner product with which to define
%                                 the mass matrix.
%                                 String.  Default value = 'ip_simple'.
%                 Supported values are:
%                   - 'ip_simple'
%                   - 'ip_tpf'
%                   - 'ip_quasitpf'
%                   - 'ip_rt'
%
%               - Type        -- Well control type.
%                                String.  Default value is 'bhp'.
%                  Supported values are:
%                    - 'bhp'  - Well is controlled by bottom hole pressure
%                               target.
%                    - 'rate' - Well is controlled by Rate target.
%
%               - Val         -- Well control target value.  Interpretation
%                                of this value is dependent upon 'Type'.
%                                Default value is 0.  If the well 'Type' is
%                                'bhp', then 'Val' is given in unit Pascal
%                                and if the 'Type' is 'rate', then 'Val' is
%                                given in unit m^3/second.
%
%               - Radius      -- Well bore radius (in unit of meters).
%                                Either a single, scalar value which
%                                applies to all perforations or a vector of
%                                radii (one radius value for each
%                                perforation).
%                                Default value: Radius = 0.1 (i.e., 10 cm).
%
%               - Dir         -- Well direction.
%                                Either a single character which applies to
%                                all perforations or a character string
%                                containing one character for each
%                                perforation which specifies the direction
%                                of the corresponding perforation.
%                                Default value: Dir = 'z', meaning a
%                                vertical well.
%                  Supported values are:
%                    - 'x' - Well is perforated in model 'x' direction.
%                    - 'y' - Well is perforated in model 'y' direction.
%                    - 'z' - Well is perforated in model 'z' direction.
%
%               - Name        -- Well name.  String.
%                                Default value:
%                                  name = sprintf('W%d', numel(W) + 1).
%
%               - Comp_i      -- Fluid composition for injection wells.
%                                Vector of saturations.
%                                Default value:
%                                  Comp_i = [1, 0, 0] (water injection)
%
%               - WI          -- Well index. Vector of length
%                                numel(cellInx).
%                                Default value: WI = -1*ones(numC,1),
%                                meaning calculate WI from grid block data.
%
%               - Kh          -- Permeability thickness. Vector of
%                                length numel(cellInx).
%                                Default value: Kh = -1*ones(numC,1),
%                                meaning calculate Kh from grid block data.
%                                Value is ignored if WI is supplied for all
%                                cells.
%
%               - Skin        -- Skin factor for computing effective well
%                                bore radius. Scalar value or vector of
%                                length numel(cellInx). Default value: 0.0
%                                (no skin effect). Value is ignored if WI
%                                is supplied for all cells.
%
%              - RefDepth     -- Reference depth for bottom hole pressure
%                                target measured along gravity vector.
%                                Default value: minimal depth in G.
%
%              - Sign         -- Well type: production (sign = -1) or
%                                injection (sign = 1). Default value: []
%                                (no sign).
%
% RETURNS:
%   W       - Updated (or freshly created) well structure, each element
%             of which has the following fields:
%               cells -- Grid cells perforated by this well (== cellInx).
%               type  -- Well control type (== Type).
%               val   -- Target control value (== Val).
%               r     -- Well bore radius (== Radius).
%               dir   -- Well direction (== Dir).
%               WI    -- Well index.
%               dZ    -- Displacement of each well perforation
%                        measured from 'highest' horizontal contact (i.e.
%                        the 'TOP' contact with the minimum 'Z' value
%                        counted amongst all cells perforated by this
%                        well).
%               name  -- Well name (== Name).
%               compi -- Fluid composition--only used for injectors
%                        (== Comp_i).
%
% EXAMPLE:
%   simpleWellExample
%
% SEE ALSO:
%   verticalWell, addSource, addBC.

%{
#COPYRIGHT#
%}

% $Date: 2009-10-23 15:35:42 +0200 (fr, 23 okt 2009) $
% $Revision: 3064 $

if ~isempty(W) && ~isfield(W, 'WI'),
   error(msgid('CallingSequence:Changed'), ...
        ['The calling sequence for function ''addWell'' has changed\n', ...
         'Please use\n\tW = addWell(W, G, rock, cellInx, ...)\n', ...
         'from now on.']);
end

error(nargchk(4, inf, nargin, 'struct'));
numC = numel(cellInx);
opt = struct('InnerProduct', 'ip_simple',                  ...
             'Dir'         , 'z',                          ...
             'Name'        , sprintf('W%d', numel(W) + 1), ...
             'Radius'      , 0.1,                          ...
             'Type'        , 'bhp',                        ...
             'Val'         , 0,                            ...
             'Comp_i'      , [1, 0, 0],                    ...
             'WI'          , -1*ones(numC,1),              ...
             'Kh'          , -1*ones(numC,1),              ...
             'Skin'        , zeros(numC, 1),               ...
             'refDepth'    , [],                           ...
             'Sign'        , []);

opt = merge_options(opt, varargin{:});

WI = reshape(opt.WI, [], 1);

assert (numel(WI)       == numC)
assert (numel(opt.Kh)   == numC);
assert (numel(opt.Skin) == numC || numel(opt.Skin) == 1);
assert (strcmp(opt.Type, 'rate') || strcmp(opt.Type, 'bhp'));

if numel(opt.Skin) == 1, opt.Skin = opt.Skin(ones([numC, 1]));  end

% Set reference depth default value.
if isempty(opt.refDepth),
   g_vec = gravity();
   dims  = size(G.nodes.coords, 2);

   if norm(g_vec(1:dims)) > 0,
      g_vec = g_vec ./ norm(g_vec);
      opt.refDepth = min(G.nodes.coords * g_vec(1:dims)');
   else
      opt.refDepth = 0;
   end
end
ip = opt.InnerProduct;

% Initialize Well index - WI. ---------------------------------------------
% Check if we need to calculate WI or if it is supplied.

compWI = WI < 0;

if any(compWI) % calculate WI for the cells in compWI
   WI(compWI) = wellInx(G, rock, opt.Radius, opt.Dir, cellInx(:), ...
                       ip, opt, compWI);

   % The supplied WI is much likely a standard Peaceman WI. Issue warning
   % if this WI is used with other solver than TPFA
   if ~all(compWI) && (~strcmp(ip, 'ip_tpf') || ~strcmp(ip, 'ip_quasitpf'))
      warning(msgid('wellInx'), ...
      ['Using a combination of supplied and computed well indices (WI).\n', ...
       'The computed WI are generated for use with inner product %s,\n', ...
       'but this might not be the case for the supplied WI entries.'], ...
        opt.InnerProduct)
   end
   
   dWK(compWI) = wellInxDK(G, rock, opt.Radius, opt.Dir, cellInx(:), ip, opt, compWI); %derivative WI w.r.t K
else  %use supplied WI

   % The supplied WI is much likely a standard Peaceman WI. Issue warning
   % if this WI is used with other solver than TPFA
   if ~strcmp(ip, 'ip_tpf') || ~strcmp(ip, 'ip_quasitpf')
       warning(msgid('wellInx'), ...
       ['Using supplied well indices. Make sure that the supplied \n',...
        'well indices are generated for use with inner product %s.'], ip)
   end
end

% Set well sign (injection = 1 or production = -1)
% for bhp wells or rate controlled wells with rate = 0.
if ~isempty(opt.Sign),
   if sum(opt.Sign == [-1, 1]) ~= 1,
      error(msgid('Sign:NonUnit'), 'Sign must be -1 or 1');
   end
   if strcmp(opt.Type, 'rate') && (sign(opt.Val) ~= 0) ...
         && (opt.Sign ~= sign(opt.Val)),
      warning(msgid('Sign'), ...
             ['Given sign does not match sign of given value. ', ...
              'Setting w.sign = sign( w.val )'])
   end
else
   if strcmp(opt.Type, 'rate'),
      if opt.Val == 0,
         warning(msgid('Sign'), 'Given value is zero, prod or inj ???');
      else
         opt.Sign = sign(opt.Val);
      end
   end
end

% Add well to well structure. ---------------------------------------------
%
W  = [W; struct('cells'   , cellInx(:),           ...
                'type'    , opt.Type,             ...
                'val'     , opt.Val,              ...
                'r'       , opt.Radius,           ...
                'dir'     , opt.Dir,              ...
                'WI'      , WI,                   ...
                'dZ'      , getDepth(G, cellInx(:))-opt.refDepth, ...
                'name'    , opt.Name,             ...
                'compi'   , opt.Comp_i,           ...
                'refDepth', opt.refDepth,         ...
                'sign'    , opt.Sign,             ...
                'dWK'     , dWK )];               %derivative WI w.r.t K

%--------------------------------------------------------------------------
% Private helper functions follow
%--------------------------------------------------------------------------


function WI = wellInx(G, rock, radius, welldir, cells, innerProd, opt, inx)

[dx, dy, dz] = cellDims(G   , cells);
k            = permDiag(rock, cells);

welldir = lower(welldir);

if numel(welldir) == 1, welldir = welldir(ones([size(k,1), 1])); end
if numel(radius)  == 1, radius  = radius (ones([size(k,1), 1])); end

assert (numel(welldir) == size(k,1));
assert (numel(radius)  == size(k,1));

[d1, d2, ell, k1, k2] = deal(zeros([size(k,1), 1]));

ci = welldir == 'x';
[d1(ci), d2(ci), ell(ci), k1(ci), k2(ci)] = ...
   deal(dy(ci), dz(ci), dx(ci), k(ci,2), k(ci,3));

ci = welldir == 'y';
[d1(ci), d2(ci), ell(ci), k1(ci), k2(ci)] = ...
   deal(dx(ci), dz(ci), dy(ci), k(ci,1), k(ci,3));

ci = welldir == 'z';
[d1(ci), d2(ci), ell(ci), k1(ci), k2(ci)] = ...
   deal(dx(ci), dy(ci), dz(ci), k(ci,1), k(ci,2));


% Table look-up (interpolation) for mimetic or 0.14 for tpf
wc  = wellConstant(d1, d2, innerProd);

re1 = 2 * wc .* sqrt((d1.^2).*sqrt(k2 ./ k1) + ...
                     (d2.^2).*sqrt(k1 ./ k2));
re2 = (k2 ./ k1).^(1/4) + (k1 ./ k2).^(1/4);

re  = reshape(re1 ./ re2, [], 1);
ke  = sqrt(k1 .* k2);

Kh = reshape(opt.Kh, [], 1); i = Kh < 0;
Kh(i) = ell(i) .* ke(i);

WI = 2 * pi * Kh./(log(re ./ radius) + reshape(opt.Skin, [], 1));

if any(WI < 0),
   if any(re < radius)
      error(id('WellRadius'), ...
               ['Equivalent radius in well model smaller than well', ...
               'radius causing negative well index'].');      
   else   
      error(id('SkinFactor'), ...
            'Large negative skin factor causing negative well index.');
   end
end

% Only return calculated WI for requested cells
WI = WI(inx);

%--------------------------------------------------------------------------

function wellConst = wellConstant(d1, d2, innerProd)
% table= [ratio mixedWellConstant]
table = [ 1, 0.292; ...
          2, 0.278; ...
          3, 0.262; ...
          4, 0.252; ...
          5, 0.244; ...
          8, 0.231; ...
          9, 0.229; ...
         16, 0.220; ...
         17, 0.219; ...
         32, 0.213; ...
         33, 0.213; ...
         64, 0.210; ...
         65, 0.210];

switch innerProd,
   case {'ip_tpf', 'ip_quasitpf'},
      wellConst = 0.14;
   case {'ip_rt', 'ip_simple'},
      ratio = max(round(d1./d2), round(d2./d1));
      wellConst = interp1(table(:,1), table(:,2), ratio, ...
                          'linear', 'extrap');
   otherwise,
      error(id('InnerProduct:Unknown'), ...
            'Unknown inner product ''%s''.', innerProd);
end

%--------------------------------------------------------------------------

function Z = getDepth(G, cells)
direction = gravity();
dims      = size(G.nodes.coords, 2);
if norm(direction(1:dims)) > 0,
   direction = direction ./ norm(direction(1:dims));
end
Z = G.cells.centroids(cells, :) * direction(1:dims).';

%--------------------------------------------------------------------------

function [dx, dy, dz] = cellDims(G, ix)
% cellDims -- Compute physical dimensions of all cells in single well
%
% SYNOPSIS:
%   [dx, dy, dz] = cellDims(G, ix)
%
% PARAMETERS:
%   G  - Grid data structure.
%   ix - Cells for which to compute the physical dimensions (bounding
%        boxes).
%
% RETURNS:
%   dx, dy, dz -- Size of bounding box for each cell.  In particular,
%                 [dx(k),dy(k),dz(k)] is Cartesian BB for cell ix(k).

n = numel(ix);
[dx, dy, dz] = deal(zeros([n, 1]));

ixc = cumsum([0; double(G.cells.numFaces)]);
ixf = cumsum([0; double(G.faces.numNodes)]);

for k = 1 : n,
   c = ix(k);                                     % Current cell
   f = G.cellFaces(ixc(c) + 1 : ixc(c + 1), 1);   % Faces on cell
   e = mcolon(ixf(f) + 1, ixf(f + 1));            % Edges on cell

   nodes  = unique(G.faceNodes(e, 1));            % Unique nodes...
   coords = G.nodes.coords(nodes,:);              % ... and coordinates

   % Compute bounding box
   m = min(coords);
   M = max(coords);

   % Size of bounding box
   dx(k) = M(1) - m(1);
   dy(k) = M(2) - m(2);
   dz(k) = M(3) - m(3);
end

%--------------------------------------------------------------------------

function p = permDiag(rock, inx)
if isempty(rock) || ~isfield(rock, 'perm'),
   error(id('Rock:Empty'), ...
         'Empty input argument ''rock'' is not supported');
elseif size(rock.perm, 2) == 1,
   p = rock.perm(inx, [1, 1, 1]);
elseif size(rock.perm, 2) == 3,
   p = rock.perm(inx, :);
else
   p = rock.perm(inx, [1, 4, 6]);
end

%--------------------------------------------------------------------------

function s = id(s)
s = ['addWell:', s];

%--------------------------------------------------------------------------

function dWK = wellInxDK(G, rock, radius, welldir, cells, innerProd, opt, inx)

load Kreal;
Kreal     = reshape( Kreal, [1,G.cells.num]);
rock.perm = Kreal'*100*milli*darcy;


[dx, dy, dz] = cellDims(G   , cells);
k            = permDiag(rock, cells);

welldir = lower(welldir);

if numel(welldir) == 1, welldir = welldir(ones([size(k,1), 1])); end
if numel(radius)  == 1, radius  = radius (ones([size(k,1), 1])); end

assert (numel(welldir) == size(k,1));
assert (numel(radius)  == size(k,1));

[d1, d2, ell, k1, k2] = deal(zeros([size(k,1), 1]));

ci = welldir == 'x';
[d1(ci), d2(ci), ell(ci), k1(ci), k2(ci)] = ...
   deal(dy(ci), dz(ci), dx(ci), k(ci,2), k(ci,3));

ci = welldir == 'y';
[d1(ci), d2(ci), ell(ci), k1(ci), k2(ci)] = ...
   deal(dx(ci), dz(ci), dy(ci), k(ci,1), k(ci,3));

ci = welldir == 'z';
[d1(ci), d2(ci), ell(ci), k1(ci), k2(ci)] = ...
   deal(dx(ci), dy(ci), dz(ci), k(ci,1), k(ci,2));


% Table look-up (interpolation) for mimetic or 0.14 for tpf
wc  = wellConstant(d1, d2, innerProd);

re1 = 2 * wc .* sqrt((d1.^2).*sqrt(k2 ./ k1) + ...
                     (d2.^2).*sqrt(k1 ./ k2));
re2 = (k2 ./ k1).^(1/4) + (k1 ./ k2).^(1/4);

re  = reshape(re1 ./ re2, [], 1);
ke  = sqrt(k1 .* k2);

Kh = reshape(opt.Kh, [], 1); i = Kh < 0;
Kh(i) = ell(i) .* ke(i);
% Kh(i) = ell(i);

dWK = 2 * pi * Kh./(log(re ./ radius) + reshape(opt.Skin, [], 1));
% dWK = log(re ./ radius) ./ -2 * pi * Kh;

% Only return calculated WI for requested cells
dWK = dWK(inx);
