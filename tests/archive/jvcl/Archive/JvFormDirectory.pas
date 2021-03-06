{-----------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/MPL-1.1.html

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either expressed or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: JvFormDirectory.PAS, released on 2001-02-28.

The Initial Developer of the Original Code is Sébastien Buysse [sbuysse@buypin.com]
Portions created by Sébastien Buysse are Copyright (C) 2001 Sébastien Buysse.
All Rights Reserved.

Contributor(s): Michael Beck [mbeck@bigfoot.com].

Last Modified: 2000-02-28

You may retrieve the latest version of this file at the Project JEDI's JVCL home page,
located at http://jvcl.sourceforge.net

Known Issues:
-----------------------------------------------------------------------------}

{$I JVCL.INC}

unit JvFormDirectory;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, JvCustomBox, JvDirectoryBox, JvSpeedButton, Buttons;

type
  TFormDir = class(TForm)
    Image1: TImage;
    Bevel1: TBevel;
    GroupBox1: TGroupBox;
    StaticText1: TStaticText;
    StaticText2: TStaticText;
    StaticText3: TStaticText;
    BUButton1: TJvSpeedButton;
    BUButton2: TJvSpeedButton;
    BUButton3: TJvSpeedButton;
    BUDirectoryBox1: TJvDirectoryBox;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
  public
  end;

implementation

{$R *.DFM}

procedure TFormDir.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  canclose := Self.tag = 1;
end;

end.
