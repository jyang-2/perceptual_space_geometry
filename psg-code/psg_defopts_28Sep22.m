function opts_use=psg_defopts(opts)
%opts_use=psg_defopts(opts) sets up default options for perceptual space geometry experiments
%
% opts: optional overrides, may be omitted
%
% opts_use: full options structure
%
%  See also  FILLDEFAULT, PSG_SESSONFIG_MAKE, PSG_COND_WRITE, PSG_SETUP_DEMO, PSG_COND_CREATE,
%   PSG_COND_WRITE, PSG_COND_CREATE.
%
if (nargin<1)
    opts=struct;
end
%
%logging and calculation
opts=filldefault(opts,'if_log',0); %1 to log
opts=filldefault(opts,'if_cumulative',0); %whether to compute triad statistics for each session cumulatively
%
%session parameters
opts=filldefault(opts,'cond_nstims',25);
opts=filldefault(opts,'cond_ncompares',8);
opts=filldefault(opts,'cond_novlp',2);
opts=filldefault(opts,'cond_nsess',10);
opts=filldefault(opts,'refseq',1); %randomization method for reference stimuli shared across contexts
opts=filldefault(opts,'refseq_labels',{'random','ordered'}); %labels for refseq
%
%options related to stimulus example reuse, mostly for psg_cond_create
opts=filldefault(opts,'example_infix_mode',1); %whether to use different examples of each stimulus across sessions, or within sessions, or not at all
opts=filldefault(opts,'example_infix_labels',{'different examples across all sessions','different examples within session','single example','single example, no infix'});
opts=filldefault(opts,'example_infix_string','_'); %separator between stimulus name and example number
opts=filldefault(opts,'example_infix_zpad',3); %number of digits to zero-pad 
%
%file name creation options
opts=filldefault(opts,'sess_zpad',2); %zero-padding in session name
opts=filldefault(opts,'stim_filetype','png');
%
opts_use=opts;
return
