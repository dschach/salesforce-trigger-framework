# Installing the app using a Scratch Org

1. Set up your environment. Follow the steps in the [Quick Start: Lightning Web Components](https://trailhead.salesforce.com/content/learn/projects/quick-start-lightning-web-components/) Trailhead project. The steps include:

<ul>
   <li>Enable Dev Hub in your org or Trailhead Playground</li>
   <li>Install <a target="_blank" href="https://developer.salesforce.com/tools/vscode/en/getting-started/install/#visual-studio-code">Visual Studio Code</a></li>
   <li>Install <a target="_blank" href="https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm">Salesforce CLI</a></li>
   <li>Install the <a target="_blank" href="https://developer.salesforce.com/tools/vscode/en/getting-started/install/#salesforce-extensions-for-visual-studio-code">Visual Studio Code Salesforce extensions</a></li>
</ul>

1. If you haven't already done so, authorize your hub org and provide it with an alias (**myhuborg** in the command below):

   ```plaintext
   sfdx auth:web:login --setdefaultdevhubusername --setalias myhuborg
   ```

1. Clone the duplicatehandling repository:

   ```plaintext
   git clone https://github.com/dschach/salesforce-trigger-framework
   cd salesforce-trigger-framework
   ```

1. Create your scratch org

   - Using the included script
      From the VSCode command line, run [orginit script](scripts/orginit.sh)
      ```plaintext
      . scripts/orginit.sh
      ```

   - Using CLI manually

     1. Create a scratch org and provide it with an alias (**triggerHandler** in the command below):

        ```plaintext
        sf org create scratch --set-default --definition-file config/project-scratch-def.json --alias triggerHandler
        ```

        This will create a new scratch org and install all metadata in this repository

     2. Push the app to your scratch org:

        ```plaintext
        sf deploy metadata
        ```

     3. Open the scratch org:

        ```plaintext
        sf org open
        ```
