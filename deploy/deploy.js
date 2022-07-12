module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy} = deployments;
    const {account0, account1} = await getNamedAccounts();

    const charityAddr = '0xb3658D2f36bE726A595857CF535fFfa4Ed5184a8';
    const devAddr = '0x30Ff03ac2c912A6651f99b8FaAA4390115d39819';

    await deploy('SanenergyToken', {
      from: account0,
      args: [charityAddr, devAddr],
      log: true,
    });
  };