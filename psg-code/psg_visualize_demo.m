%psg_visualize_demo: demonstrate visualization of psg coordinates
%
% plotformats sets number of dimensions, number to plot at once
%
% 29Jan23: enable plotting of model fits: data read via psg_get_coordsets
%         rather than psg_read_coorddata
% 17Jun23: allows for some points not assigned to rays, optional connecting of nearest neighbors
% 27Jun23: mode with single-point for rays, and suppressing ray angle calculation and plotting (for bcpm24pt and similar)
% 23Feb24: clean up if_origin logic
% 15Oct24: add computation and visualization of multipliers
%
%  See also: PSG_GET_COORDSETS, PSG_READ_COORDDATA, PSG_FINDRAYS, PSG_DEFOPTS, BTC_DEFINE,
%  PSG_PLOTCOORDS, PSG_RAYFIT, PSG_RAYANGLES, PSG_SPOKES_SETUP, PSG_VISUALIZE, PSG_PLOTANGLES.
%  PSG_PROCRUSTES_DEMO, PSG_COLORS_LEGACY, PSG_RAYMULTS, PSG_PLOTMULTS.
%
if ~exist('opts_plot') opts_plot=struct(); end %for psg_plotcoords
if ~exist('opts_vis') opts_vis=struct(); end %for psg_visualize
if ~exist('opts_read') opts_read=struct();end %for psg_read_coord_data
if ~exist('opts_rays') opts_rays=struct(); end %for psg_findrays
if ~exist('opts_fit') opts_fit=struct(); end %for psg_rayfit
if ~exist('opts_ang')  opts_ang=struct(); end %for psg_rayangles
if ~exist('opts_mult') opts_mult=struct(); end %for psg_raymults
if ~exist('opts_visang')  opts_visang=struct(); end %for psg_plotangles
if ~exist('opts_vismult') opts_vismult=struct(); end %for psg_plotangles
if ~exist('opts_qpred') opts_qpred=struct(); end %for psg_qformpred
if ~exist('data_fullname') data_fullname=[]; end
if ~exist('setup_fullname') setup_fullname=[]; end
%
opts_read=filldefault(opts_read,'if_spray',0); %default to not define rays by single points
if (opts_read.if_spray==0) %if ray mode is never used, color is irrelevant
    opts_plot=psg_colors_legacy(opts_plot);
    if isfield(opts_plot,'colors')
        opts_visang.colors=opts_plot.colors;
        opts_vismult.colors=opts_plot.colors;
    end
end
%
if ~exist('plotformats')
    plotformats=[2 2;3 2;3 3;4 3;5 3]; %dim model, number of dims at a time
end
if ~exist('if_plotrays') if_plotrays=1; end
if ~exist('if_plotbids') if_plotbids=0; end
if ~exist('if_plotrings') if_plotrings=0; end
if ~exist('if_nearest_neighbor') if_nearest_neighbor=-1; end
%
if_spray=getinp('1 to define rays by single points, suppress ray angle calculations, and suppress ray angle plots','d',[0 1],opts_read.if_spray);
if (if_spray)
    opts_rays.ray_minpts=1;
    if_plotrays=0;
end
%
nsets=1;
opts_read=filldefault(opts_read,'if_log',1);
[sets,ds,sas,rayss,opts_read_used,opts_rays_used,opts_qpred_used]=psg_get_coordsets(opts_read,opts_rays,opts_qpred,nsets);
d=ds{1};
sa=sas{1};
rays=rayss{1};
opts_read_used=opts_read_used{1};
opts_rays_used=opts_rays_used{1};
opts_rays_used.permute_raynums=opts_read_used.permute_raynums;
%
disp(sprintf('stimulus coordinates group along %2.0f rays',rays.nrays));
origin_ptr=find(rays.whichray==0);
if length(origin_ptr)==1
    disp(sprintf('origin found at stimulus %1.0f (%s)',origin_ptr,sa.typenames{origin_ptr}));
    offset_ptr=getinp('pointer for stimulus to plot at origin or 0 for none or -1 for centroid)','d',[-1 sa.nstims],origin_ptr);
else
    disp('origin not found');
    offset_ptr=0;
    opts_fit.if_origin=0;
end
opts_vis.offset_ptr=offset_ptr;
opts_vis.if_pcrot=getinp('1 to apply pca rotation','d',[0 1],0);
%
ray_counts=full(sparse(rays.whichray(rays.whichray>0),ones(sum(rays.whichray>0),1),1,rays.nrays,1));
for iray=1:rays.nrays
    disp(sprintf('ray %2.0f: %2.0f points; endpoint: %s',iray,ray_counts(iray),sprintf('%5.2f',rays.endpt(iray,:))));
end
%
if_plotrays=getinp('1 to superimpose plots of (unidirectional, through origin) rays ','d',[0 1],if_plotrays);
if_plotbids=getinp('1 to superimpose plots of (bidirectional, not through origin) rays','d',[0 1],if_plotbids);
opts_plot.if_rings=getinp('1 to plot rings','d',[0 1],if_plotrings);
opts_plot.if_nearest_neighbor=getinp('1 to connect nearest neighbors, 0 not, -1 if unassigned points','d',[-1 1],if_nearest_neighbor);
%
%for each dimension model, find best-fitting signed and unsigned rays, including the origin
%
dim_list=sets{1}.dim_list;
model_dim_max=max(dim_list);
d_rayfit=cell(1,model_dim_max); %coordinate structure of best-fitting rays
d_bidfit=cell(1,model_dim_max); %coordinate structure of best-fitting bidirectional rays
ray_ends=cell(1,model_dim_max); %unidirectional ray directions at max
bid_ends=cell(1,model_dim_max); %bidirectional  ray directions at max
%
angles_ray=cell(1,model_dim_max); %angle data, unidirectional
angles_bid=cell(1,model_dim_max); %angle data, bidirectional
%
opts_fit_used=cell(model_dim_max,2); %d1: model dim, d2: 1+if_bid
opts_ang_used=cell(model_dim_max,2);
opts_mult_used=cell(model_dim_max,2);
%
if ~if_spray
    for idimptr=1:length(dim_list)
        idim=dim_list(idimptr);
        %compute ray fits
        [d_rayfit{idim},ray_ends{idim},opts_fit_used{idim,1}]=psg_rayfit(d{idim},rays,filldefault(opts_fit,'if_bid',0));
        [d_bidfit{idim},bid_ends{idim},opts_fit_used{idim,2}]=psg_rayfit(d{idim},rays,filldefault(opts_fit,'if_bid',1));
        %compute angles between fitted rays
        [angles_ray{idim},opts_ang_used{idim,1}]=psg_rayangles(ray_ends{idim},sa,rays,opts_ang);
        [angles_bid{idim},opts_ang_used{idim,2}]=psg_rayangles(bid_ends{idim},sa,rays,opts_ang);
        %compute multipliers for fitted rays
        [mults_ray{idim},opts_mult_used{idim,1}]=psg_raymults(ray_ends{idim},sa,rays,opts_mult);
        [mults_bid{idim},opts_mult_used{idim,2}]=psg_raymults(bid_ends{idim},sa,rays,opts_mult);
    end
end
%
file_string=sprintf('%s %s',opts_read_used.setup_fullname,opts_read_used.data_fullname);
%
% simple plot: 2- and 3-way combinations of all axes
%
opts_vis.if_plotrays=if_plotrays;
opts_vis.if_plotbids=if_plotbids;
opts_vis.d_rayfit=d_rayfit;
opts_vis.d_bidfit=d_bidfit;
opts_vis.file_string=file_string;
[opts_vis_used,opts_plot_used]=psg_visualize(plotformats,d,sa,rays,opts_vis,opts_plot);
if ~if_spray
    opts_visang.vis_string=file_string;
    opts_visang_ray_used=psg_plotangles(angles_ray,sa,rays,opts_visang);
    opts_visang_bid_used=psg_plotangles(angles_bid,sa,rays,opts_visang);
    opts_vismult.vis_string=file_string;
    opts_vismult_ray_used=psg_plotmults(mults_ray,sa,rays,opts_vismult);
    opts_vismult_bid_used=psg_plotmults(mults_bid,sa,rays,opts_vismult);
else
    opts_visang_ray_used=[];
    opts_visang_bid_used=[];
    opts_vismult_ray_used=[];
    opts_vismult_bid_used=[];
end
