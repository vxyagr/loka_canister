# loka_canister

Loka onchain bitcoin mining platform canisters on ICP

Local deployment :
make sure you have installed npm, nodejs, and ICP Motoko SDK




##deploy tokens (there are 3, this one is example) :
dfx deploy lkrc --argument '( record {                     
      name = "LKRC";                         
      symbol = "LKRC";                           
      decimals = 6;                                           
      fee = 0;                                        
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

and then mint some

dfx canister call lkrc mint '(record {
  to = record {owner = principal "aovwi-4maaa-aaaaa-qaagq-cai"};
  amount=1_000_000_000_000
},)'




##deploy nft :
dfx deploy --argument '(principal "your-minting-principal")'

dfx ledger fabricate-cycles --all
##deploy loka :

dfx deploy betalk

