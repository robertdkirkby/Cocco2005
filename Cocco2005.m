% Cocco (2005) - Portfolio Choice in the Presence of Housing
%
% Special thanks to Zachary Orlando whos codes answered many questions I
% had that the C2005 paper left unclear: https://github.com/ZacharyOrl/Replication-Project
%
% This is not a perfect replication as many details of the model have been
% lost to time. Joao Cocco reports by email (not to me, but the info was
% passed to me) that the original codes have been lost to the sands of time
% so a full replication is not possible.

% Cocco (2005) does not say anything much about how many points are used for
% housing, omega and u (p must use same number of points as eta). 
% So I just make some stuff up. He says Tauchen-Hussey to discretize eta,
% and uses 3 points.

% Note: C2005, while estimating emprically that the correlation between aggregate income shocks (eta) and house prices (p)
% is rho_eta_p=0.553, actually imposes that rho_eta_p=1 to solve the mode [this eliminates a state variable, as p is now just 'same' thing as eta].
% Code here allows you to drop this imposition:
impose_rho_eta_p=1; % =1 is what C2005 does

n_d=[51,301,2]; % riskyshare, savings, riskyinvest [riskyinvest is just so I can still refine riskyshare out of the ReturnFn, it does not add functionality, just makes codes faster/less memory]
n_a=[6,2,101]; % ,housing, has-ever-participated-in-stock-market, assets [the 'riskyasset' must be the last endogenous state]
if impose_rho_eta_p==1 % =1 is what C2005 does
    n_z=[5,1]; % p has to follow eta, easiest way to do this is to use a joint grid on z (that way the number of inputs to the ReturnFn, etc., are same as when using impose_rho_eta_p=0)
elseif impose_rho_eta_p==0
    n_z=[5,5]; % eta (persistent earnings shock), p (house price)
    % eta and p must use same number of points (because of the discretization proceedure used here, which requires that)
end
n_e=[5,2]; % omega (transitory earnings shock), and the 'forced to move house' shock (C2005 calls this InvMove_t)
n_u=7; % returns to risky asset
N_j=10; % 5 year periods, ages 25-29 to 70-74.

vfoptions.riskyasset=1;
simoptions.riskyasset=1;
vfoptions.refine_d=[0,1,2]; % number of d1, d2, and d3 decision variables
% zero 'd1' decision variable that appears in ReturnFn but not aprimeFn (not expecations)
% one 'd2' decision variable that appears in aprimeFn but not ReturnFn
% one 'd3' decision variable (savings) which appears in both ReturnFn and aprimeFn (expecations)

Names_i={'nohighschool','highschool','college'};


% eta & p are labelled by Cocco (2005) as 'aggregate risk', but because of the exercise being done
% here this is just an irrelevant label with no meaningful content so they are treated by this 
% code as idiosyncratic shocks. If you wanted to simulate the model economy over time (or do general eqm) you would 
% need to treat them as aggregate shocks, but since paper only reports age-profiles it is not 
% relevant and we ignore it, treating them both as idiosyncratic shocks.

% Cocco (2005) uses the gross returns Rtilde, R_d and R_f. I use the net returns rtilde, r_d and r_f [R=1+r].

% Paper contains a confusion between eta and etatilde, and omega and
% omegatilde. As far as I can tell the whole thing is just a massive typo and they
% are the same. C2005 uses etatilde and omegatilde when discussing the
% income process on page 538, but then uses eta and omega when discussing
% the correlation of house prices and incomes on page 539. The alternative
% is that eqn (4) which relates etatilde to eta is not a typo (I expect it
% is) in which case the whole paragraph around it is completely wrong as
% etatilde would not be AR(1).

% Cocco (2005) distinguishes 'B' (treasury bills) from 'D' (mortgage debt),
% but they are just the same thing, here 'assets', and just pay different
% returns depending on if assets is positive (B) or negative (D).

% Note: Cocco (2005) allows for u to correlate with innovations to z.
% rho_{epsilon,iota} on page 540 (although his calibration sets this correlation to zero). 
% This (two different types of shocks correlating; one is markov the other is a between-period 
% i.i.d.) is not currently possible in VFI Toolkit. 
% So below I just hardcode that rho_{epsilon,iota}=0. You could 'trick' the
% toolkit into solving the model with rho_{epsilon,iota}>0, by modelling u as a markov (and thus
% they could be correlated), but then you have to model two standard endogenous
% states instead of one riskyasset, so while the toolkit could solve the
% model it would be a fairly poor way to go about doing this.

% C2005 is really weird, as there appears to be no possibility of not
% owning a house. Normally you would put "housing services" into the model,
% and then houseing services would be a fraction of housing owned, and
% renters (households that own zero housing) would be able to rent housing
% services. But C2005 puts housing itself directly into the utility
% function, which also rules out owning zero housing as that would result
% in negative infinite utility.
% We still need an H=0 point in the grid on housing because "there is no
% initial level of housing", C2005 pg 541. But in the first period everyone
% has to buy housing, and then will always have housing from then on.

% C2005 does not say what the model units should be. I just run it in
% dollars which seems to work okay (I like to run models in same units as
% data comes in, makes it easier to see when things are not working as $20
% is clearly not an annual income, whereas if you have odd units 1.2 may or
% may not make sense as an annual income).


%% 
% Demographics and ageing
Params.agejshifter=20; % first model period is age 25-29 (this is 5 below, as add 5 per period)
Params.age=25:5:70; % age that corresponds to the model period (model period covers ages from this to this plus four)
% C2005 says "dies at 75, which I assume means 'end of 74' rather than 'end of 79, which is the period starting at 75'
Params.agej=1:1:N_j; % model period
Params.J=N_j; % final period (C2005 calls this T)
Params.Jr=9; % retirement age (C2005 calls this K) "retires at age 65"

% Preferences
Params.beta=0.96^5; % discount factor, 0.96 on an annual basis, model period is 5 years
Params.gamma=5; % curvature of utility
Params.theta=0.1; % value of housing consumption relative to other consumption

% Earnings: ln(earnings)=kappa_ij + eta + omega
% kappa is deterministic fn of age
% eta is AR(1)
% omega is i.i.d.
% kappa_j:
Params.kappa_j.nohighschool=log([80000, 90000, 92000, 90000, 85000, 80000, 75000, 65000, 63000, 63000]);
Params.kappa_j.highschool=log([108000, 116000, 125000, 130000, 130000, 128000, 120000, 105000, 80000, 80000]);
Params.kappa_j.college=log([130000, 140000, 155000, 170000, 185000, 195000, 193000, 180000, 110000, 110000]);
% These values for kappa_j were eyeballed from the C2005 Fig 1 by Zachary Orlando (https://github.com/ZacharyOrl/Replication-Project/blob/main/parameters/life_cycle_income_1_eyeballed_from_paper.csv, and 2 and 3 in same place)
% Note that these are 'five year incomes'
% eta:
Params.rho_eta=0.748; % autocorrelation (C2005 call this phi)
% Params.sigma_eta=0.019; % std dev of eta
% Params.sigma_eta_epsilon=sqrt(1-Params.rho_eta^2)*Params.sigma_eta; % std dev of innovations to eta (C2005 call this sigma_epsilon; doesn't explain the calc of this from sigma_eta, but is standard for an AR(1) so I expect this is what he did)
Params.sigma_eta_epsilon=0.019; % I think C2005 is just loose on notation and calls it the std dev of eta when he means the std dev of the innovations to eta
% So then
Params.sigma_eta=Params.sigma_eta_epsilon/sqrt(1-Params.rho_eta^2);
% omega
Params.sigma_omega.nohighschool=0.136; % std dev of omega
Params.sigma_omega.highschool=0.131; % std dev of omega
Params.sigma_omega.college=0.133; % std dev of omega

% Housing
Params.Hmin=20000; % minimum house size, $20000 (not clear how this translates into model units)
Params.prob_forcedtomove=0.03; % probability hit with a 'shock' and forced to move (C2005 calls this pi)
Params.lambda_h=0.08; % monetary cost of selling a house
Params.delta_h=0.01*5; % annual maintainence costs of housing (C2005 calibrates this as depreciation rather than maitainence cost; 1% depreciation on an annual basis)
Params.downpayment=0.15; % downpayment (as fraction of house) (C2005 calls this d)

% House Price Shocks
Params.b=0.016*5; % real house price growth [this is the five-year rate]
Params.sigma_p=0.062; % std. dev. of house prices
Params.rho_eta_p=0.553; % correlation between house prices and aggregate income shocks
if impose_rho_eta_p==1 % C2005 does this in his results, but you can turn it off here
    Params.rho_eta_p=1;
end
% C2005 does not report an autocorrelation between house prices and
% aggregate income shocks because it is implicit in his imposition of
% rho_eta_p=1. But here I need one as it is possible to turn this off.
Params.rho_p=Params.rho_eta_p;
% Note: This would be better modelled as a bivariate VAR(1) on (eta,p).

% Housing and 'aggregate' labor shocks
% To keep things simple, C2005 just sets eta=kappa_eta*p. Notice that eta=kappa_eta*p 
% should mean that stddev(eta)=kappa_eta*stddev(p). Since C2005 does not
% appear to report value for kappa_eta I use this to calculate it
Params.kappa_eta=Params.sigma_eta/Params.sigma_p;
% Note: 1/kappa_eta is approx 2, so house prices are not that much more volatile than earnings.

% Risky asset returns,
% rtilde=log(iota), iota~N(mu,sigma_iota^2)
% Calculation of mu [X is normal, then E[exp(X)]=exp(𝜇+𝜎^2/2), etc.]
Params.sigma_iota=0.1674; % std dev of innovations
Params.mu=log(0.10-(Params.sigma_iota^2)/2); % mean return [want mean of rtilde to be 10%]

% Safe assets
Params.r_f=0.02; % return on 'treasury bills' (C2005 uses R_f=1+r_f)
Params.r_d=0.04; % return on debt (C2005 uses R_d=1+r_d)

% Stock-market participation costs (paid first time entering)
Params.spcost=1000; % C2005 calls this F. It is calibrated to $1000 dollars (not clear how this translates into model units)

%% Grids
% Endogenous states
asset_grid=-50000+550000*linspace(0,1,n_a(3))'.^3; % assets, -50000 to 500000, ^3 puts more points near zero [originally max as 5million, but no-one went anywhere near it]
% make the point closest to zero be exactly zero
[~,zeroassetsind]=min(abs(asset_grid)); % start people with zero savings [THIS IS A GUESS, NEED TO FIND WHAT C2005 DOES?]
asset_grid(zeroassetsind)=0;


housing_grid=Params.Hmin*[0,1,2,3,4,5]'; 
% C2005 does not say much about the grid on housing. He specifies that Hmin is a point, and is the minimum value of housing.
% We need H=0 so everyone can start there in period 1, but from then on they will always avoid it (as it would give -Inf utility).

stockparticipation_grid=[0;1];

a_grid=[housing_grid; stockparticipation_grid; asset_grid]; % stacked column vectors

% Decision variables
riskyshare_grid=linspace(0,1,n_d(1))';
savings_grid=asset_grid(1)+0.95*(asset_grid(end)-asset_grid(1))*linspace(0,1,n_d(2))'.^3;
% make the point closest to zero be exactly zero
[~,zerosavingsind]=min(abs(savings_grid)); % start people with zero savings [THIS IS A GUESS, NEED TO FIND WHAT C2005 DOES?]
savings_grid(zerosavingsind)=0;

riskyinvest_grid=[0;1]; % =1 if you invest in any amount of riskyshare (can only have riskyshare>0 when riskyinvest=1)

d_grid=[riskyshare_grid; savings_grid; riskyinvest_grid]; % stacked column vectors


% Exogenous states

% risky asset return: u~logN(mu,sigma_iota^2)
[u_grid,pi_u]=discretizeAR1_FarmerToda(Params.mu,0,Params.sigma_iota,n_u);
pi_u=pi_u(1,:)'; % i.i.d.
u_grid=exp(u_grid);

% Earnings: AR(1) eta
% House prices: p
% These two are correlated, so have to jointly discretize them
% z=(eta,p)
if impose_rho_eta_p==1
    % Cocco (2005) just discretizes eta, then sets p=eta/kappa_eta.
    [eta_grid,pi_eta]=discretizeAR1_FarmerToda(0,Params.rho_eta,Params.sigma_eta_epsilon,n_z(1));
    % You should in this case just remove p from state space, and use p=eta/kappa_eta in codes.
    % But I want you to be able to not impose the perfect correlation, so I
    % still need p in the state space and so we have to create,
    p_grid=eta_grid/Params.kappa_eta; % Eqn (6) of C2005
    % Set them up as a joint grid, makes the transitions easier to set up
    z_grid=[eta_grid, p_grid]; % joint grid
    pi_z=pi_eta;
elseif impose_rho_eta_p==0
    % We have need the Covar matrix for z
    % We have the two standard deviations, and the correlation.
    % Creating CovarMatrix from the Correlation matrix and the standard deviations is a standard calculation
    stddevmatrix=diag([Params.sigma_eta_epsilon, Params.sigma_p]);
    corrmatrix=[1,Params.rho_eta_p; Params.rho_eta_p,1];
    CoVarMatrix=stddevmatrix*corrmatrix*stddevmatrix;
    [z_grid,pi_z]=discretizeVAR1_FarmerToda([0;0],[Params.rho_eta,0; 0,Params.rho_p],CoVarMatrix,n_z);
    % Note: I don't use [0; Params.b] as the constants, because the Params.b is added in later inside the ReturnFn.
end


% Earnings: iid omega, differs by permanent type
[omega_grid_nohighschool,pi_omega_nohighschool]=discretizeAR1_FarmerToda(0,0,Params.sigma_omega.nohighschool,n_e(1));
pi_omega_nohighschool=pi_omega_nohighschool(1,:)'; % iid
[omega_grid_highschool,pi_omega_highschool]=discretizeAR1_FarmerToda(0,0,Params.sigma_omega.nohighschool,n_e(1));
pi_omega_highschool=pi_omega_highschool(1,:)'; % iid
[omega_grid_college,pi_omega_college]=discretizeAR1_FarmerToda(0,0,Params.sigma_omega.nohighschool,n_e(1));
pi_omega_college=pi_omega_college(1,:)'; % iid

% 'Involuntary move' shock [=1 forces you to move house]
InvMove_grid=[0;1]; % one is the 'forced to move'
pi_InvMove=[1-Params.prob_forcedtomove; Params.prob_forcedtomove];


%% Using an iid variable, so tell vfoptions and simoptions about it

vfoptions.n_e=n_e;
vfoptions.e_grid.nohighschool=[omega_grid_nohighschool; InvMove_grid];
vfoptions.pi_e.nohighschool=kron(pi_InvMove,pi_omega_nohighschool); % kron() in reverse order
vfoptions.e_grid.highschool=[omega_grid_highschool; InvMove_grid];
vfoptions.pi_e.highschool=kron(pi_InvMove,pi_omega_highschool); % kron() in reverse order
vfoptions.e_grid.college=[omega_grid_college; InvMove_grid];
vfoptions.pi_e.college=kron(pi_InvMove,pi_omega_college); % kron() in reverse order
simoptions.n_e=vfoptions.n_e;
simoptions.e_grid=vfoptions.e_grid;
simoptions.pi_e=vfoptions.pi_e;

%% riskyasset, set up aprimeFn
vfoptions.aprimeFn=@(riskyshare,savings,riskyinvest,u,r_f,r_d)...
    Cocco2005_aprimeFn(riskyshare,savings,riskyinvest,u,r_f,r_d);

simoptions.aprimeFn=vfoptions.aprimeFn;
simoptions.d_grid=d_grid;
simoptions.a_grid=a_grid;

vfoptions.n_u=n_u;
vfoptions.u_grid=u_grid;
vfoptions.pi_u=pi_u;
simoptions.n_u=vfoptions.n_u;
simoptions.u_grid=vfoptions.u_grid;
simoptions.pi_u=vfoptions.pi_u;

%%
DiscountFactorParamNames={'beta'};

% note: savings is input to ReturnFn, but riskyshare is not (as per vfoptions.refine_d)
ReturnFn=@(savings,riskyinvest,hprime,spprime,h,sp,a,eta,p,omega,InvMove,delta_h,lambda_h,spcost,theta,gamma,downpayment,b,r_f,kappa_j,agej,J,beta)...
    Cocco2005_ReturnFn(savings,riskyinvest,hprime,spprime,h,sp,a,eta,p,omega,InvMove,delta_h,lambda_h,spcost,theta,gamma,downpayment,b,r_f,kappa_j,agej,J,beta);

%% Solve the value fn problem
vfoptions.lowmemory=2; % there are heaps of shocks, this will loop over z and e, so slower but reduces memory use
vfoptions.verbose=1;
tic;
[V,Policy]=ValueFnIter_Case1_FHorz_PType(n_d,n_a,n_z,N_j,Names_i,d_grid,a_grid,z_grid,pi_z,ReturnFn,Params,DiscountFactorParamNames,vfoptions);
vftime=toc

%% Agent distribution
% C2005 article says little about this.
jequaloneDist=zeros([n_a,n_z,n_e],'gpuArray');
h0ind=1; % C2005 explictly says everyone starts with zero housing
sp0ind=1; % definitionally, everyone starts having never invested in stock market before
[~,asset0ind]=min(abs(asset_grid)); % start people with zero savings [THIS IS A GUESS, NEED TO FIND WHAT C2005 DOES?]
z0ind=[3,1]; % start with median shock
e0ind=[3,1]; % start with median earnings shock, and without a forced-move-house shocks (but this is irrelevant as everyone has to buy a house in first period anyway)
jequaloneDist(h0ind,sp0ind,asset0ind,z0ind(1),z0ind(2),e0ind(1),e0ind(2))=1;

% Age Weights: Following is from Zachary Orlando
% (https://github.com/ZacharyOrl/Replication-Project/blob/main/Initialize_Model.jl)
% # Weighting grid for simulations - taken from Cocco(2005) 
%                             #    nhs  hs    clg
%     wts::Matrix{Float64} = [
%                                 0.01  0.06  0.02;   # 25–29
%                                 0.02  0.08  0.04;   # 30–34
%                                 0.01  0.10  0.06;   # 35–39
%                                 0.0175  0.075  0.0675;   # 40–44 - Values slightly adjusted to account for Cocco rounding
%                                 0.01  0.05  0.03;   # 45–49
%                                 0.0175  0.035  0.0175;   # 50–54 - Values slightly adjusted so the row sum matches Cocco
%                                 0.02  0.04  0.02;   # 55–59
%                                 0.02  0.03  0.02;   # 60–64
%                                 0.02  0.04  0.01;   # 65–69
%                                 0.02  0.03  0.01    # 70–74
%                                 ]         
%
% Guessing he got them out of some table in C2005?
% Based on this I set
AAweights=[0.01,0.06,0.02; 0.02, 0.08, 0.04; 0.01, 0.10, 0.06; 0.0175, 0.075, 0.0675; 0.01, 0.05, 0.03; 0.0175, 0.035, 0.0175; 0.02, 0.04, 0.02; 0.02, 0.03, 0.02; 0.02, 0.04, 0.01; 0.02, 0.03, 0.01];
AAweights_ii=sum(AAweights,1);
AAweights_jj=sum(AAweights,2);

AgeWeightsParamNames={'mewj'};
PTypeDistParamNames={'ptypemass'};

Params.mewj=AAweights_jj./sum(AAweights_jj); % normalize to one
Params.ptypemass=AAweights_ii./sum(AAweights_ii); % normalize to one
% This is an approximate version of C2005. You can easily do his version
% manually. I like this as one it is cleaner in terms of the model.

tic;
StationaryDist=StationaryDist_Case1_FHorz_PType(jequaloneDist,AgeWeightsParamNames,PTypeDistParamNames,Policy,n_d,n_a,n_z,N_j,Names_i,pi_z,Params,simoptions);
statdisttime=toc


% look at how much of the asset grid is actually used
assetDist.college=squeeze(sum(sum(sum(sum(sum(sum(StationaryDist.college,1),2),4),5),6),7)); % (a,j)
assetDist.highschool=squeeze(sum(sum(sum(sum(sum(sum(StationaryDist.highschool,1),2),4),5),6),7)); % (a,j)
assetDist.nohighschool=squeeze(sum(sum(sum(sum(sum(sum(StationaryDist.nohighschool,1),2),4),5),6),7)); % (a,j)
assetDist.college=cumsum(assetDist.college,1)./sum(assetDist.college,1);
assetDist.highschool=cumsum(assetDist.highschool,1)./sum(assetDist.highschool,1);
assetDist.nohighschool=cumsum(assetDist.nohighschool,1)./sum(assetDist.nohighschool,1);

figure(1);
subplot(3,1,1); plot(asset_grid, assetDist.college)
subplot(3,1,2); plot(asset_grid, assetDist.highschool)
subplot(3,1,3); plot(asset_grid, assetDist.nohighschool)

%% Calculate some life-cycle profiles to see if things look reasonable

FnsToEvaluate.assets=@(riskyshare,savings,riskyinvest,hprime,spprime,h,sp,a,eta,p,omega,InvMove) a;
FnsToEvaluate.housing=@(riskyshare,savings,riskyinvest,hprime,spprime,h,sp,a,eta,p,omega,InvMove,b,agej) ((1+b)^(agej-1)*exp(p))*hprime;
FnsToEvaluate.earnings=@(riskyshare,savings,riskyinvest,hprime,spprime,h,sp,a,eta,p,omega,InvMove,kappa_j) exp(kappa_j+eta+omega);
FnsToEvaluate.everinvested=@(riskyshare,savings,riskyinvest,hprime,spprime,h,sp,a,eta,p,omega,InvMove,kappa_j) spprime;
FnsToEvaluate.totalriskysavings=@(riskyshare,savings,riskyinvest,hprime,spprime,h,sp,a,eta,p,omega,InvMove,kappa_j) riskyshare*savings*(savings>0);
FnsToEvaluate.totalsavings=@(riskyshare,savings,riskyinvest,hprime,spprime,h,sp,a,eta,p,omega,InvMove,kappa_j) savings*(savings>0);

tic;
AgeConditionalStats=LifeCycleProfiles_FHorz_Case1_PType(StationaryDist,Policy,FnsToEvaluate,Params,n_d,n_a,n_z,N_j,Names_i,d_grid,a_grid,z_grid,simoptions);
acstime=toc



figure(2);
subplot(5,1,1); plot(Params.age,AgeConditionalStats.assets.Mean/1000)
title('Assets (thousands of dollars)')
subplot(5,1,2); plot(Params.age,AgeConditionalStats.housing.Mean/1000)
title('Housing (value, in thousands of dollars)')
subplot(5,1,3); plot(Params.age,AgeConditionalStats.earnings.Mean/1000,Params.age,AgeConditionalStats.earnings.college.Mean/1000,Params.age,AgeConditionalStats.earnings.highschool.Mean/1000,Params.age,AgeConditionalStats.earnings.nohighschool.Mean/1000)
title('Earnings (thousands of dollars)')
legend('Average','College', 'High School','No High School')
subplot(5,1,4); plot(Params.age,AgeConditionalStats.everinvested.Mean)
title('Fraction of population that ever invested in shares')
subplot(5,1,5); plot(Params.age,AgeConditionalStats.totalriskysavings.Mean./AgeConditionalStats.totalsavings.Mean)
title('Fraction of total savings in risky assets')



