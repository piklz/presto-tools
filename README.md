### presto-tools

<h1 align="center">
  <a name="logo" href=""><img src="https://lh3.googleusercontent.com/-NA9EMF1ws5s/VxVp_qcGlYI/AAAAAAAAI-Y/RArFmhkOZ-kEeJ9AtchvCxZ8M7DqsgLggCCo/s576-Ic42/05%2BPresto.png" alt="presto" width="200"></a>
  <br>
  Perfectly Rationalized Engine for Superior Tidiness and Organization  (Tool kit)
</h1>





## Features
### Some scripts to help make your presto|raspberry pi experience better!

 - `presto-tools_install .sh` 
        (The actual install script for this kit ) 
 - `presto_bashwelcome.sh` 
        (Gives you nice info on your pi' running state)
 - `presto_update_full.py`  
          automatically one shot updates your whole docker-stacked system 
          with image cleanup at the end for a clean, space saving, smooth docker experience ,
          ie. can be used with a cron job ,for example to execute it every week and update the containers and prune the left over images?
          (see below for instructions )



## Quick Start
- Automatic one click Way:
<pre><code>curl -sSL  https://raw.githubusercontent.com/piklz/presto-tools/main/scripts/presto-tools_install.sh | bash </code></pre>
 ( if you prefer to see whats happening try the manual ways below)

- MANUAL Way
- install git using a command: 
<pre><code>sudo apt-get install git</code></pre>

- Clone the repository with:
<pre><code>git clone https://github.com/piklz/presto-tools ~/presto-tools</code></pre>

- Enter the directory:

<pre><code>cd ~/presto-tools/</code></pre>
-  and run:
<pre><code>./scripts/presto-tools_install.sh</code></pre>

## Customise !

Theres a file the user can customise env options in the ~/presto-tools/scripts/ directory,"presto_config.defaults" with this you can copy(cp) and call it "presto_config.local"
<pre><code>cp ~/presto-tools/scripts/presto_config.defaults ~/presto-tools/scripts/presto_config.local</code></pre>
- open new file in nano and edit the values as needed; next time you login it will show the info chosen
<pre><code>sudo nano ~/presto-tools/scripts/presto_config.local</code></pre>
change values from 0 to 1 to enable.. etc
<pre><code>[in nano] ctrl + x +  Y + ENTER </code></pre> to save new file

<h1 align="center">  
<a name="" href="https://www.buymeacoffee.com/pixelpiklz"><img src="https://img.buymeacoffee.com/api/?url=aHR0cHM6Ly9jZG4uYnV5bWVhY29mZmVlLmNvbS91cGxvYWRzL3Byb2ZpbGVfcGljdHVyZXMvMjAyMi8wNy8wOFlYYUJXMlRvbWc5M0xqLnBuZ0AzMDB3XzBlLndlYnA=&creator=pixelpiklz&design_code=1&design_color=%23ff813f&slug=pixelpiklz" alt="presto" width="200"></a>
</h1>
<h4 align="center">   support me : https://www.buymeacoffee.com/pixelpiklz </h4>
