function F=Cocco2005_ReturnFn(savings,riskyinvest,hprime,spprime,h,sp,a,eta,p,omega,InvMove,delta_h,lambda_h,spcost,theta,gamma,downpayment,b,r_f,kappa_j,agej,J,beta)

F=-Inf;

% first time stock-market participation cost
spcostpaid=0;
if sp==0 && riskyinvest>0
    spcostpaid=spcost;
end

% p is log(P) housing shocks
% p is markov, which captures the stochastic
% But P also has a determistic growth of b every period
% So I compute P itself as
P=((1+b)^(agej-1))*exp(p);
% This might be a little fast and loose, but C2005 is not clear on this as
% he has the deterministic growth in p, but then does not discretize it in
% a way that includes this constant drift (because he just sets it
% proportional to eta which does not have drift).

% housing costs
housingcosts=0; % just to keep GPU happy
if InvMove==0
    if hprime==h % same house
        housingcosts=delta_h*h*P; % just the depreciation
    else
        % depreciation, transaction costs, and sell old minus buy new
        housingcosts=(1-delta_h-lambda_h)*h*P-hprime*P; 
        % lambda_h*h: transaction cost of changing house, as percent "of the unit being exchanged"
    end
elseif InvMove==1
    % Got a moving shock. So even if housesize is the same you are still having to buy it.
    % depreciation, transaction costs, and sell old minus buy new
    housingcosts=(1-delta_h-lambda_h)*h*P-hprime*P;
end

% earnings
earnings=exp(kappa_j+eta+omega);
% DO I NEED TO MAKE EARNINGS ZERO IN RETIREMENT???

%% 
% budget constraint
c=a+earnings-savings-spcostpaid-housingcosts;
% Note: the returns to safe and risky assets are all handled elsewhere and already implicit in the value of a (assets) here.

% utility fn
if c>0 && hprime>0
    % Note: C2005 uses hprime in the utility fn, not h.
    F=(((c^(1-theta))*(hprime^theta))^(1-gamma))/(1-gamma);
end


%% Deal with some remaining situations

% Share market participation (force it to evolve appropriately)
if sp==0 && riskyinvest>0
    % participating in share market for first time
    if spprime==0
        F=-Inf;
    end
elseif sp==0 && riskyinvest==0
    % not participating in the share market, so remain sp=0
    if spprime==1
        F=-Inf;
    end
end
if sp==1 && spprime==0
    % sp is an absorbing state
    F=-Inf;
end

% Collateral constraint
if savings<-(1-downpayment)*P*h
    % collateral constraint
    % Note that when savings<0, you cannot be investing in risky assets anyway
    % can only have mortgage if own house
    F=-Inf;
    % Note: this covers the h=0 case as it becomes a constraint that aprime>=0
end

% Warm-glow of bequests
if agej==J % terminal period
    bequest=savings*(1+r_f)+(1-delta_h-lambda_h)*P*hprime; % Eqn 13 of C2005
    % I cheat a bit here and just assume you get warm-glow off your savings
    % as the safe rate of return, rather than doing the full calculation
    % based on the stock market returns that occur after you die. Is anyway
    % going to make no real difference to results.
    if bequest>0
        warmglow=((bequest)^(1-gamma))/(1-gamma);
        F=F+beta*warmglow;
    else
        F=-Inf;
    end
end


end
