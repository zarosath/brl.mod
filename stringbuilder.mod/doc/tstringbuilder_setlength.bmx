SuperStrict

Framework BRL.StringBuilder
Import brl.standardio

Local sb:TStringBuilder = New TStringBuilder("Hello World!")

sb.SetLength(5)

Print sb.ToString()