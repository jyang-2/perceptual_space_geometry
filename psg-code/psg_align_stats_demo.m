%psg_align_knit_demo: demonstration of alignment and knitting together of multiple datasets
% that have partially overlapping stimuli
%
% Does a consensus alignment of overlapping data that need to be 'knitted together, i.e., not
% all stimuli are present in each condition, and writes the consensus
% data and metadata file.  Assumes that this is a raw data or model file, no previous entries in pipeline.
%
%
% Compared to psg_align_knit_demo, this is designed for datasets that have largely the same stimuli, though perhaps missing a few --
%  rather than constructing a space that is of higher dimension than any of the component datasets.
%  The resulting consensus dataset is considered as a "denoised" version of the components, rather than an augmented one.
%  Therefore, compared to psg_align_knit_demo:
%   * Does analysis with and without allowing scale
%   * Computes variance explained, by dataset and stimulus
%   * Uses a shuffle of stimuli within datasets to determine whether variance explained by each dimension is significant
%   * Does NOT allow for creation of a consensus dataset that has higher imension than any component
%   * Does not do visualizations
%   * Does not use ray descriptors
%   * Component datasets not stripped of NaN's
%
% Notes:
%  All datasets must have dimension lists beginning at 1 and without gaps
%  Aligned datasets and metadata (ds_align,sas_align) will have a NaN where there is no match
%  For classes such as mater and domain and aux, there should be the same
%      number of stimuli in each file, since btc_specoords is an identity matrix, with one entry for each stimulus.
%
%  See also: PSG_ALIGN_COORDSETS, PSG_COORD_PIPE_PROC, PSG_GET_COORDSETS, PSG_READ_COORDDATA,
%    PROCRUSTES_CONSENSUS, PSG_WRITE_COORDDATA, PSG_COORD_PIPE_UTIL, PSG_ALIGN_KNIT_DEMO.
%

%main structures and workflow:
%ds{nsets},                sas{nsets}: original datasets and metadata
%ds_align{nsets},          sas_align{nsets}: datasets with NaN's inserted to align the stimuli
%ds_knitted{ia},            sa_pooled: consensus rotation of ds_align, all stimuli, and metadata; ia=1 for no scaling, ia=2 for scaling
%ds_components{ia}{nsets}, sas_align{nsets}: components of ds_knitted, corresponding to original datasets, but with NaNs -- these are Procrustes transforms of ds_align
%
if ~exist('opts_read') opts_read=struct();end %for psg_read_coord_data
if ~exist('opts_align') opts_align=struct(); end %for psg_align_coordsets
if ~exist('opts_pcon') opts_pcon=struct(); end % for procrustes_consensus
%
disp('This will attempt to knit together two or more coordinate datasets and do statistics.');
%
if ~exist('nshuffs') nshuffs=500; end
%
nshuffs=getinp('number of shuffles','d',[0 10000],nshuffs);
if nshuffs>0
    if_frozen=getinp('1 for frozen random numbers, 0 for new random numbers each time, <0 for a specific seed','d',[-10000 1],1);
    if (if_frozen~=0) 
        rng('default');
        if (if_frozen<0)
            rand(1,abs(if_frozen));
        end
    else
        rng('shuffle');
    end
end
%
opts_read.input_type=1;
opts_align=filldefault(opts_align,'if_log',1);
%
opts_pcon=filldefault(opts_pcon,'allow_reflection',1);
opts_pcon=filldefault(opts_pcon,'allow_offset',1);
opts_pcon=filldefault(opts_pcon,'allow_scale',0); 
opts_pcon=filldefault(opts_pcon,'max_niters',1000); %nonstandard max
%
nsets_signed=getinp('number of datasets (negative to use dialog box, data only)','d',[-100 100]);
[sets,ds,sas,rayss,opts_read_used,opts_rays_used,opts_qpred_used]=psg_get_coordsets(opts_read,[],[],nsets_signed); %get the datasets
nsets=length(sets); %number of sets actually read
%
% check that all dimensions are present
%
for iset=1:nsets
    if (iset==1)
        dim_list_all=sets{iset}.dim_list;
    else
        dim_list_all=intersect(dim_list_all,sets{iset}.dim_list);
    end
    if length(dim_list_all)~=length(1:max(dim_list_all))
        disp(sprintf('some dimensions are missing in set %1.0f',iset))
    end
end
max_dim_all=max(dim_list_all); %max dimension available across all sets
%
% tally missing stimuli in input datasets and align according to stimuli present
%
nstims_each=zeros(1,nsets);
stims_nan=cell(1,nsets);
disp('before alignment of stimuli')
for iset=1:nsets
    nstims_each(iset)=sas{iset}.nstims;
    stims_nan{iset}=find(isnan(ds{iset}{1}));
    disp(sprintf('set %2.0f: %2.0f stimuli (%2.0f are NaN), label: %s',iset,nstims_each(iset),length(stims_nan{iset}),sets{iset}.label))
end
[sets_align,ds_align,sas_align,ovlp_array,sa_pooled,opts_align_used]=psg_align_coordsets(sets,ds,sas,opts_align); %align the stimulus names
nstims_all=sets_align{1}.nstims;
disp(sprintf('total stimuli: %3.0f',nstims_all));
%
disp('after alignment of stimuli')
stims_nan_align=cell(1,nsets);
stims_each_align=zeros(1,nsets);
for iset=1:nsets
    nstims_each_align(iset)=sas_align{iset}.nstims;
    stims_nan_align{iset}=find(isnan(ds_align{iset}{1}));
    disp(sprintf('set %2.0f: %2.0f stimuli (%2.0f are NaN), label: %s',iset,nstims_each_align(iset),length(stims_nan_align{iset}),sets_align{iset}.label))
end
disp('overlap matrix')
disp(ovlp_array'*ovlp_array);
%
%make permutations for shuffling
%
permutes=cell(1,nsets);
for iset=1:nsets
    stims_nonan=setdiff(1:nstims_each_align,stims_nan_align{iset});
    permutes{iset}=zeros(max_dim_all,nstims_each_align(iset),nshuffs);
    for ishuff=1:nshuffs
        for ip=1:max_dim_all
            permutes{iset}(ip,stims_nonan,ishuff)=stims_nonan(randperm(length(stims_nonan))); %onl shuffle nonans
        end
    end
    permutes{iset}(:,stims_nan_align{iset},:)=repmat(stims_nan_align{iset}(:)',[max_dim_all 1 nshuffs]); %nan's don't get shuffled
    disp(sprintf(' set %2.0f: created shuffles for %3.0f stimuli',iset,length(stims_nonan)));
end
%
pcon_dim_max=getinp('maximum dimension for the consensus alignment dataset to be created (same dimensoin used in each component)','d',[1 max_dim_all],max_dim_all);
pcon_init_method=getinp('method to use for initialization (>0: a specific set, 0 for PCA, -1 for PCA with forced centering, -2 for PCA with forced non-centering','d',[-2 nsets],0);
if pcon_init_method>0
    opts_pcon.initialize_set=pcon_init_method;
else
    if pcon_init_method==0
        opts_pcon.initialize_set='pca';
    elseif pcon_init_method==-1
        opts_pcon.initialize_set='pca_center';
    else
        opts_pcon.initialize_set='pca_nocenter';
    end
end
%
%reformat data for consensus calculation
%
z=cell(pcon_dim_max,1);
for ip=1:pcon_dim_max
    z{ip}=zeros(nstims_all,ip,nsets);
    for iset=1:nsets
        z{ip}(:,:,iset)=ds_align{iset}{ip}(:,[1:ip]); %only include data up to pcon_dim_use
        z{ip}(opts_align_used.which_common(:,iset)==0,:,iset)=NaN; % pad with NaN's if no data
    end
end
%overlaps indicates same stimulus (from ovlp_array) and also
%that the coordinates are not NaN's
coords_isnan=reshape(isnan(z{1}),[nstims_all,nsets]);
disp(sprintf('number of overlapping stimuli in component removed because coordinates are NaN'));
disp(sum(coords_isnan.*ovlp_array,1));
opts_pcon.overlaps=ovlp_array.*(1-coords_isnan);
%
disp('overlap matrix from stimulus matches')
disp(ovlp_array'*ovlp_array);
disp(sprintf('overlapping coords in component datasets with values of NaN that are removed from overlaps'));
disp(opts_pcon.overlaps'*opts_pcon.overlaps);
%
results=struct;
consensus=cell(pcon_dim_max,2); %d1: dimnension, d2: allow scale=[0,1]
znew=cell(pcon_dim_max,2);
ts=cell(pcon_dim_max,2);
details=cell(pcon_dim_max,2);
opts_pcon_used=cell(pcon_dim_max,2);
ds_knitted=cell(1,2);
ds_components=cell(1,2); %allow scale or not
rmsdev_setwise=zeros(pcon_dim_max,nsets,2);
rmsdev_stimwise=zeros(pcon_dim_max,nstims_all,2);
rmsdev_overall=zeros(pcon_dim_max,1,2); %rms distance, across all datasets and stimuli
counts_setwise=zeros(1,nsets);
counts_stimwise=zeros(1,nstims_all);
%
for allow_scale=0:1
    ia=allow_scale+1;
    disp(' ')
    disp(sprintf(' calculations with allow_scale=%1.0f',allow_scale));
    opts_pcon.allow_scale=allow_scale;
    ds_knitted{ia}=cell(1,nsets);
    ds_components{ia}=cell(1,nsets);
    for ip=1:pcon_dim_max
        %do unshuffled
        [consensus{ip,ia},znew{ip,ia},ts{ip,ia},details{ip,ia},opts_pcon_used{ip,ia}]=procrustes_consensus(z{ip},opts_pcon);
        disp(sprintf(' creating Procrustes consensus for dim %1.0f based on component datasets, iterations: %4.0f, final total rms dev per coordinate: %8.5f',...
            ip,length(details{ip,ia}.rms_change),sqrt(sum(details{ip,ia}.rms_dev(:,end).^2))));
        ds_knitted{ia}{ip}=consensus{ip,ia};
        for iset=1:nsets
            ds_components{ia}{iset}{1,ip}=znew{ip}(:,:,iset);
        end
        sqdevs=sum((znew{ip,ia}-repmat(consensus{ip,ia},[1 1 nsets])).^2,2); %squared deviation of consensus from rotated component
        %rms deviation across each dataset, summed over coords, normalized by the number of stimuli in each dataset
        rmsdev_setwise(ip,:,ia)=reshape(sqrt(mean(sqdevs,1,'omitnan')),[1 nsets]);
        counts_setwise=squeeze(sum(~isnan(sqdevs),1))';
        %rms deviation across each stimulus, summed over coords, normalized by the number of sets that include the stimulus
        rmsdev_stimwise(ip,:,ia)=reshape(sqrt(mean(sqdevs,3,'omitnan')),[1 nstims_all]);
        counts_stimwise=(sum(~isnan(sqdevs),3))';
        %rms devaition across all stimuli and coords
        rmsdev_overall(ip,1,ia)=sqrt(mean(sqdevs(:),'omitnan'));
        counts_overall=sum(~isnan(sqdevs(:)));
        %shuffles: across all coordds and incrementally
        for ishuff=1:nshuffs
            %do shuffles

        end %ishuff
    end %ip
end %ia
results.nstims=nstims_all;
results.nsets=nsets;
results.nshuffs=nshuffs;
results.dim_max=pcon_dim_max;
results.ds_desc='ds_[knitted|components]: top dim is no scaling vs. scaling';
results.ds_consensus=ds_knitted;
results.ds_components=ds_components;
results.sa_consensus=sa_pooled; %metadata for ds_knitted
results.sas_components=sas_align; %metadata for each of ds_components
results.rmsdev_desc='d1: dimension, d2: nsets or nstims, d3: no scaling vs. scaling';
results.rmsdev_setwise=rmsdev_setwise;
results.rmsdev_stimwise=rmsdev_stimwise;
results.rmsdev_overall=rmsdev_overall;
results.counts_desc='d1: 1, d2: nsets or nstims';
results.counts_setwise=counts_setwise;
results.counts_stimwise=counts_stimwise;
results.counts_overall=counts_overall;


for allow_scale=0:1
    ia=allow_scale+1;
    disp(sprintf(' calculations with allow_scale=%1.0f',allow_scale));
    if getinp('1 to write a file with consensus (knitted) coordinate data and metadata','d',[0 1])
    %
        opts_write=struct;
        opts_write.data_fullname_def='[paradigm]pooled_coords_ID.mat';
        %
        sout_consensus=struct;
        sout_consensus.stim_labels=strvcat(sa_pooled.typenames);
        %
        opts=struct;
        opts.pcon_dim_max=pcon_dim_max; %maximum consensus dimension created   
        opts.pcon_dim_max_comp=pcon_dim_max; %maximum component dimension used
        opts.details=details(:,ia); %details of Procrustes alignment
        opts.opts_read_used=opts_read_used; %file-reading options
        opts.opts_align_used=opts_align_used; %alignment options
        opts.opts_pcon_used=opts_pcon_used(:,ia); %options for consensus calculation for each dataset
        sout_consensus.pipeline=psg_coord_pipe_util('consensus',opts,sets);
        opts_write_used=psg_write_coorddata([],ds_knitted{ia},sout_consensus,opts_write);
        %
        metadata_fullname_def=opts_write_used.data_fullname;
        metadata_fullname_def=metadata_fullname_def(1:-1+min(strfind(cat(2,metadata_fullname_def,'_coords'),'_coords')));
        if isfield(sa_pooled,'nsubsamp')
            metadata_fullname_def=cat(2,metadata_fullname_def,sprintf('%1.0f',sa_pooled.nsubsamp));
        end
        metadata_fullname=getinp('metadata file name','s',[],metadata_fullname_def);
        s=sa_pooled;
        save(metadata_fullname,'s');
    end
end
