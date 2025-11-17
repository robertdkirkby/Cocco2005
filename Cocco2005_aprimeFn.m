function aprime=Cocco2005_aprimeFn(riskyshare,savings,riskyinvest,u,r_f,r_d)

safeassets=(1-riskyshare)*savings;
riskyassets=riskyshare*savings;

r=r_f;
if safeassets<0
    r=r_d;
end

aprime=(1+u)*riskyassets+(1+r)*safeassets;

if riskyinvest==0 && riskyshare>0
    aprime=aprime-100000; % make sure that when choosing riskyshare>0 you will also set riskyinvest=1
end


end

