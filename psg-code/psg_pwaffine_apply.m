function y=psg_pwaffine_apply(transform,x)
% y=psg_pwaffine_apply(transform,x) applies a piecewise affine transformation
%
%  See psg_piecewise_notes.doc for details on algorithm
%
% x: original coordinates, size=[npts,dim_x]
% transform:
%   transform.b: scalar, equal to 1 (scale absorbed in Tpos, Tneg)
%   transform.T: stack of matrices, size [dim_x dim_y 2], use (:,:,1) when cuts=x*vcut'>=a, (:,:,2) when x*vcut'<=a
%   transform.c: stack of offsets, size [2 dim_y], use (1,:) when x*vcut'>=a, (2,:) when x*vcut'<a
%   transform.vcut: unit vector, as a row of size [1 dim_x], orthog to cut plane
%   transform.acut: cutpoint
%
% y: transformed coordinates, size=[npts,dim_y]
%
% opts_used: options used
%
%   See also: PSG_GEOMODELS_TEST, PSG_GEO_PWAFFINE.
%
cuts=x*transform.vcut'; %column of values of cutpoints
npts=size(x,1);
%
n_pw=size(transform.T,3); %number of pieces
ypw=zeros(npts,size(transform.T,n_pw),n_pw);
%ypw(:,:,n_pw) are the alternative values of y in each piece
for ipw=1:n_pw
    ypw(:,:,ipw)=x*transform.T(:,:,ipw)+repmat(transform.c(ipw,:),npts,1);
end
%specific to a single cut
y=ypw(:,:,1);
y(cuts<transform.acut,:)=ypw(cuts<transform.acut,:,2);
return
end

%add icut

%
% 
% function y=psg_pwaffine_apply(transform,x)
% % y=psg_pwaffine_apply(transform,x) applies a piecewise affine transformation
% %
% %  See psg_piecewise_notes.doc for details on algorithm
% %
% % x: original coordinates, size=[npts,dim_x]
% % transform:
% %   transform.b: scalar, equal to 1 (scale absorbed in Tpos, Tneg)
% %   transform.T: stack of matrices, size [dim_x dim_y 2^ncuts]
% %       for ncuts=1 (typical), use (:,:,1) when vcut*x'>=a, (:,:,2) when vcut*x'<=a
% %       for ncuts>1, compute vuct*x', compute c=vcut*x', this is a column of size ncuts
% %       use T(:,:,1)      for sign(c)=[+ + + ...+] (+ means >=0)
% %       use T(:,:,2)      for sign(c)=[- + +... +]
% %       use T(:,:,3)      for sign(c)=[+ - +... +]
% %       use T(:,:,4)      for sign(c)=[- - +... +]
% %       ....
% %       use T(:,:,2^ncut) for sign(c)=[- - -... -]
% %
