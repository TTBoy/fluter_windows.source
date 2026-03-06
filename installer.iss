[Setup]
AppName=ImageQA
AppVersion=0.0.27
DefaultDirName={pf}\qa_imageprocess
DefaultGroupName=qa_imageprocess
OutputDir=installer
OutputBaseFilename=qa_imageprocess_setup
Compression=lzma
SolidCompression=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\qa_imageprocess"; Filename: "{app}\ImageQA-0.0.27-x64.exe"
Name: "{commondesktop}\qa_imageprocess"; Filename: "{app}\ImageQA-0.0.27-x64.exe"

[Run]
Filename: "{app}\qa_imageprocess.exe"; Description: "Launch App"; Flags: nowait postinstall skipifsilent