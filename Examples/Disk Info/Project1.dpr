program UserInfo;

{$APPTYPE CONSOLE}


uses
  System.SysUtils, YaDisk,Windows,vcl.dialogs;


var
  Disk:TYaDisk;
  Login,Password,Aval,Used:String;
  sbi : TConsoleScreenBufferInfo;
begin
  writeln('Example used Yandex Disk');
  writeln;
  write('Login:');Readln(Login);
  write('Password:');Readln(Password);
  Disk:=TYaDisk.Create(Login,Password);
  Disk.GetSpaceDisk(Aval,Used);
  writeln;
  writeln('User:'+Disk.GetLogin);
  writeln('Available:'+Aval+' bytes');
  writeln('Used:'+Used+' bytes');
  readln;
end.
