
      import hre from "hardhat";

      async function main() {
        const deployer = (await hre.viem.getWalletClients())[0];
        const publicClient = await hre.viem.getPublicClient();

        console.log("Deployer:", deployer.account.address);

        const args = [];
        console.log("Args:", args);

        const contract = await hre.viem.deployContract("TuuKeepAccessControl", args);

        console.log("Address:", contract.address);
        console.log("Transaction hash:", contract.transactionHash);

        const receipt = await publicClient.getTransactionReceipt({ hash: contract.transactionHash });

        console.log("Gas used:", receipt.gasUsed.toString());
        console.log("Block number:", receipt.blockNumber.toString());

        return {
          name: "TuuKeepAccessControl",
          address: contract.address,
          transactionHash: contract.transactionHash,
          gasUsed: receipt.gasUsed.toString(),
          blockNumber: receipt.blockNumber.toString()
        };
      }

      main().then(result => {
        console.log("RESULT:", JSON.stringify(result));
        process.exit(0);
      }).catch(error => {
        console.error("ERROR:", error.message);
        process.exit(1);
      });
    