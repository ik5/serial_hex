{$MODE DELPHI}

Program testser;

uses
 synaser, sysutils;

var
  ser:TBlockSerial;
begin
  ser:=TBlockserial.Create;
  try
    ser.RaiseExcept:=True;
    ser.Connect('COM2');
    ser.Config(19200,8,'N',0,false,false);
    writeln (ser.ATCommand('ATI8'));
  finally
    ser.Free;
  end;
end.

