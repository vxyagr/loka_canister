# loka_canister

Loka onchain bitcoin mining platform canisters on ICP

Steps to deploy
1. Main Loka
2. ICRCs
3. NFT then Controller for each mining site
4. Register mining site to Main Loka canister


Local deployment :
make sure you have installed npm, nodejs, and ICP Motoko SDK


## 1. Deploy main loka canister
dfx deploy loka --argument '(record{admin = principal "your principal"})'

## 2. Deploy ICRCs

deploy tokens (there are 3 ICRCS, this one is example) :
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


## 3. Deploy NFT then mine controller

# deploy the NFT
dfx deploy (nft name) --argument '(principal "your-minting-principal")'

# deploy controller
dfx deploy (controller name) --argument '(record{admin = principal "your principal"})'

get your canister id
dfx canister id nft
dfx canister id controller

# allow controller as NFT admin
dfx canister call (nft name) setMinter '(principal "your controller id")'



## 4. Register controller and NFT to main Loka
eg :

dfx canister call loka addMiningSite '("Location", "Name" ,electricityCost; thCost; total_ = 4000; "your nft canister id in step 3"; "your control canister id in step 3")'

dfx canister call betalk addMiningSite '("Jakarta", "Velo", 0.04,4.0,4000,"ajuq4-ruaaa-aaaaa-qaaga-cai", "aovwi-4maaa-aaaaa-qaagq-cai")'

