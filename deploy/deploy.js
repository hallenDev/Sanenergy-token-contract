module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy} = deployments;
    const {account0, account1} = await getNamedAccounts();

    const charityAddr = '0x616e5138a79a4B9971a83F3A378AcC59e54Dd1B3';
    const devAddr = '0x1C39EC2fB3906b9a4517E00bB5988E942316CC08';

    await deploy('SanenergyToken', {
      from: account0,
      args: [charityAddr, devAddr],
      log: true,
    });
  };