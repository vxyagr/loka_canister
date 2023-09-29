# loka_canister

Loka onchain bitcoin mining platform canisters on ICP

dfx deploy lkrc --argument '( record {                     
      name = "LKRC";                         
      symbol = "LKRC";                           
      decimals = 6;                                           
      fee = 1_000_000;                                        
      max_supply = 1_000_000_000_000;                         
      initial_balances = vec {                                
          record {                                            
              record {                                        
                  owner = principal "a3k4v-44u5r-xnkry-u3auc-4x7ti-w7zd4-lm33y-ed5nb-ka7l5-u4eja-kqe";   
                  subaccount = null;                          
              };                                              
              100_000_000                                 
          }                                                   
      };                                                      
      min_burn_amount = 10_000;                         
      minting_account = null;                                 
      advanced_settings = null;                               
  })'


dfx deploy betalk

dfx canister call lkrc mint '(record {
  to = record {owner = principal "aovwi-4maaa-aaaaa-qaagq-cai"};
  amount=1_000_000_000_000
},)'