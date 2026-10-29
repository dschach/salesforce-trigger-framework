# Install the framework in a scratch org

1. Set up your environment. The [Quick Start: Salesforce DX](https://trailhead.salesforce.com/content/learn/projects/quick-start-salesforce-dx) Trailhead project walks through these steps:

<ul>
   <li>Enable Dev Hub in your org or Trailhead Playground</li>
   <li>Install <a target="_blank" href="https://developer.salesforce.com/tools/vscode/en/getting-started/install/#visual-studio-code">Visual Studio Code</a></li>
   <li>Install <a target="_blank" href="https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm">Salesforce CLI</a></li>
   <li>Install the <a target="_blank" href="https://developer.salesforce.com/tools/vscode/en/getting-started/install/#salesforce-extensions-for-visual-studio-code">Visual Studio Code Salesforce extensions</a></li>
</ul>

1. If you haven't already done so, authorize your Dev Hub org and give it an alias (**myhuborg** in the command below):

   ```bash
   sf org login web --set-default-dev-hub --alias myhuborg
   ```

1. Clone the salesforce-trigger-framework repository:

   ```bash
   git clone https://github.com/dschach/salesforce-trigger-framework
   cd salesforce-trigger-framework
   ```

1. Create your scratch org.

   - Using the included script

     **Note:** the script first deletes the scratch org with the alias **TriggerFramework**, if there is one, and then creates a new one with that alias. It deploys the framework and the sample handler, and opens the org.

     From the Visual Studio Code terminal, run the [orginit script](scripts/orginit.sh):

     ```bash
     bash scripts/orginit.sh
     ```

   - Using the Salesforce CLI

     1. Create a scratch org and give it an alias (**triggerHandler** in the command below). This creates an empty scratch org:

        ```bash
        sf org create scratch --set-default --definition-file config/project-scratch-def.json --alias triggerHandler
        ```

     2. Deploy the framework to your scratch org. Add `--source-dir sample-handler` to deploy the sample handler and trigger too:

        ```bash
        sf project deploy start --source-dir force-app
        ```

     3. Open the scratch org:

        ```bash
        sf org open
        ```
