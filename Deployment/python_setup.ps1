python -m venv Resources/function/.python_packages
Resources/function/.python_packages/Scripts/Activate.ps1
#pip install setuptools
#python -m pip install --upgrade pip
#Get-Location
#Get-ChildItem
#pip install -r Resources/function/requirements.txt
pip install  --target="Resources/function/.python_packages/lib/site-packages"  -r Resources/function/requirements.txt

