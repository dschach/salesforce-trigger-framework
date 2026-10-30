# Install the Framework in a Scratch Org

1. Set up your environment. The Trailhead project [Quick Start: Salesforce DX](https://trailhead.salesforce.com/content/learn/projects/quick-start-salesforce-dx) shows these steps:
   - Enable Dev Hub in your org or Trailhead Playground.
   - Install [Visual Studio Code](https://developer.salesforce.com/tools/vscode/en/getting-started/install/#visual-studio-code).
   - Install the [Salesforce CLI](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm).
   - Install the [Salesforce extensions for Visual Studio Code](https://developer.salesforce.com/tools/vscode/en/getting-started/install/#salesforce-extensions-for-visual-studio-code).

1. Authorize your Dev Hub org, if you did not do it before, and give it an alias (**myhuborg** in this command):

   ```bash
   sf org login web --set-default-dev-hub --alias myhuborg
   ```

1. Clone the salesforce-trigger-framework repository:

   ```bash
   git clone https://github.com/dschach/salesforce-trigger-framework
   cd salesforce-trigger-framework
   ```

1. Create your scratch org. Use the script or the Salesforce CLI.
   - With the script:

     **Note:** The script first deletes the scratch org with the alias **TriggerFramework**, if there is one. Then it creates a new scratch org with that alias, deploys the framework and the sample handler, and opens the org.

     In the terminal of Visual Studio Code, run the [orginit script](./scripts/orginit.sh):

     ```bash
     bash scripts/orginit.sh
     ```

   - With the Salesforce CLI:
     1. Create an empty scratch org and give it an alias (**triggerHandler** in this command):

        ```bash
        sf org create scratch --set-default --definition-file config/project-scratch-def.json --alias triggerHandler
        ```

     2. Deploy the framework to your scratch org. To deploy the sample handler and trigger too, add `--source-dir sample-handler`:

        ```bash
        sf project deploy start --source-dir force-app
        ```

     3. Open the scratch org:

        ```bash
        sf org open
        ```
