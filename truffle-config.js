const ProviderEngine = require("web3-provider-engine");
const WebsocketSubprovider = require("web3-provider-engine/subproviders/websocket.js");
const { TruffleArtifactAdapter } = require("@0x/sol-trace");
const { ProfilerSubprovider } = require("@0x/sol-profiler");
const { CoverageSubprovider } = require("@0x/sol-coverage");
const { RevertTraceSubprovider } = require("@0x/sol-trace");

const mode = process.env.MODE;

const projectRoot = "";
const solcVersion = "0.5.0";
const defaultFromAddress = "0x5409ed021d9299bf6814279a6a1411a7e866a631";
const isVerbose = true;
const artifactAdapter = new TruffleArtifactAdapter(projectRoot, solcVersion);
const provider = new ProviderEngine();

if (mode === "profile") {
    global.profilerSubprovider = new ProfilerSubprovider(
        artifactAdapter,
        defaultFromAddress,
        isVerbose
    );
    global.profilerSubprovider.stop();
    provider.addProvider(global.profilerSubprovider);
    provider.addProvider(
        new WebsocketSubprovider({ rpcUrl: "http://209.97.132.211:7545" })
    );
} else {
    if (mode === "coverage") {
        global.coverageSubprovider = new CoverageSubprovider(
            artifactAdapter,
            defaultFromAddress,
            {
                isVerbose,
            }
        );
        provider.addProvider(global.coverageSubprovider);
    } else if (mode === "trace") {
        const revertTraceSubprovider = new RevertTraceSubprovider(
            artifactAdapter,
            defaultFromAddress,
            isVerbose
        );
        provider.addProvider(revertTraceSubprovider);
    }

    provider.addProvider(
        new WebsocketSubprovider({ rpcUrl: "http://209.97.132.211:7545" })
    );
}
provider.start((err) => {
    if (err !== undefined) {
        console.log(err);
        process.exit(1);
    }
});
/**
 * HACK: Truffle providers should have `send` function, while `ProviderEngine` creates providers with `sendAsync`,
 * but it can be easily fixed by assigning `sendAsync` to `send`.
 */
provider.send = provider.sendAsync.bind(provider);

module.exports = {
    compilers: {
        solc: {
            version: "0.8.4", // Fetch exact version from solc-bin (default: truffle's version)
            // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
            settings: {
                // See the solidity docs for advice about optimization and evmVersion
                optimizer: {
                    enabled: false,
                    runs: 200,
                },
                evmVersion: "byzantium",
            },
        },
    },
    networks: {
        development: {
            provider,
            network_id: "*",
        },
    },
};
