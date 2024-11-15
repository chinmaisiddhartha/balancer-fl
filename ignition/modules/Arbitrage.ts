import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ArbitrageModule = buildModule("ArbitrageModule", (m) => {
  const arbitrage = m.contract("Arbitrage");
  return { arbitrage };
});

export default ArbitrageModule;
