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
dfx deploy betalk --argument '(record{admin = principal "rlea3-jid2o-qrpi6-w72yb-pf24t-dd6vc-6du7b-r4lnm-sccfm-mhkhu-sae"})'

dfx deploy miner --argument '(record{admin = principal "a3k4v-44u5r-xnkry-u3auc-4x7ti-w7zd4-lm33y-ed5nb-ka7l5-u4eja-kqe"})' 
## 2. Deploy ICRCs

deploy tokens (there are 3 ICRCS, this one is example) :
dfx deploy lbtc  --argument "(variant {Init = 
record {
     token_symbol = \"LBTC\";
     token_name = \"LBTC\";
     minting_account = record { owner = principal \"${MINTER}\" };
     transfer_fee = 0;
     metadata = vec {};
     feature_flags = opt record{icrc2 = true};
     initial_balances = vec { record { record { owner = principal \"${MINTER}\"; }; 1000000000000; }; };
     archive_options = record {
         num_blocks_to_archive = 1000;
         trigger_threshold = 2000;
         controller_id = principal \"${MINTER}\";
         cycles_for_archive_creation = opt 10000000000000;
     };
 }
})"

dfx deploy lklm  --argument "(variant {Init = 
record {
     token_symbol = \"LKLM\";
     token_name = \"LKLM\";
     minting_account = record { owner = principal \"${MINTER}\" };
     transfer_fee = 0;
     metadata = vec {};
     feature_flags = opt record{icrc2 = true};
     initial_balances = vec { record { record { owner = principal \"${MINTER}\"; }; 1000000000000; }; };
     archive_options = record {
         num_blocks_to_archive = 1000;
         trigger_threshold = 2000;
         controller_id = principal \"${MINTER}\";
         cycles_for_archive_creation = opt 10000000000000;
     };
 }
})"


dfx deploy lkrc  --argument "(variant {Init = 
record {
     token_symbol = \"LKRC\";
     token_name = \"LKRC\";
     minting_account = record { owner = principal \"${MINTER}\" };
     transfer_fee = 0;
     metadata = vec {};
     feature_flags = opt record{icrc2 = true};
     initial_balances = vec { record { record { owner = principal \"${MINTER}\"; }; 1000000000000; }; };
     archive_options = record {
         num_blocks_to_archive = 1000;
         trigger_threshold = 2000;
         controller_id = principal \"${MINTER}\";
         cycles_for_archive_creation = opt 10000000000000;
     };
 }
})"



dfx deploy ckbtc_ledger  --argument "(variant {Init = 
record {
     token_symbol = \"CKBTC\";
     token_name = \"CKBTC\";
     minting_account = record { owner = principal \"${MINTER}\" };
     transfer_fee = 0;
     metadata = vec {};
     feature_flags = opt record{icrc2 = true};
     initial_balances = vec { record { record { owner = principal \"${MINTER}\"; }; 1000000000000; }; };
     archive_options = record {
         num_blocks_to_archive = 1000;
         trigger_threshold = 2000;
         controller_id = principal \"${MINTER}\";
         cycles_for_archive_creation = opt 10000000000000;
     };
 }
})"

## 3. Deploy NFT then mine controller

# deploy the NFT
dfx deploy (nft name) --argument '(principal "your-minting-principal")'
dfx deploy velonft --argument '(principal "a3k4v-44u5r-xnkry-u3auc-4x7ti-w7zd4-lm33y-ed5nb-ka7l5-u4eja-kqe")'

# deploy controller
dfx deploy velo --argument '(record{admin = principal "your principal id";hashrate=0.035; electricity = 0.03; miningSiteIdparam = 1 ; siteName = "Velo"; totalHashrate =4000.0 ;})' 

dfx deploy velo --argument '(record{admin = principal "a3k4v-44u5r-xnkry-u3auc-4x7ti-w7zd4-lm33y-ed5nb-ka7l5-u4eja-kqe";hashrate=0.035; electricity = 0.035; miningSiteIdparam = 1 ; siteName = "Velo"; totalHashrate =4000.0 ;})'

get your canister id
dfx canister id nft
dfx canister id controller

# allow controller as NFT admin
dfx canister call (nft name) setMinter '(principal "your controller id")'

dfx canister call velonft setMinter '(principal "lsoez-3yaaa-aaaak-qcnnq-cai")'

# and then mint some coin to controller

dfx canister call lbtc mint '(record {
  to = record {owner = principal "ctiya-peaaa-aaaaa-qaaja-cai"};
  amount=1_000_000
},)'

## 4. Register controller and NFT to main Loka
eg :

dfx canister call loka addMiningSite '("Location", "Name" ,electricityCost; thCost; total_ = 4000; "your nft canister id in step 3"; "your control canister id in step 3")'
like this
dfx canister call betalk addMiningSite '("Jakarta", "Velo", 0.035,0.035,4000,"cuj6u-c4aaa-aaaaa-qaajq-cai", "ctiya-peaaa-aaaaa-qaaja-cai")'


loka main : rlea3-jid2o-qrpi6-w72yb-pf24t-dd6vc-6du7b-r4lnm-sccfm-mhkhu-sae
loka local : a3k4v-44u5r-xnkry-u3auc-4x7ti-w7zd4-lm33y-ed5nb-ka7l5-u4eja-kqe

current main deployment 9 Oct 2023
Loka main : l4mjr-aiaaa-aaaak-qcnmq-cai
Velo NFT : lvpcn-waaaa-aaaak-qcnna-cai
Velo Controller : lsoez-3yaaa-aaaak-qcnnq-cai
LBTC : lhjvu-2qaaa-aaaak-qcnoa-cai
LKLM : laita-xiaaa-aaaak-qcnoq-cai