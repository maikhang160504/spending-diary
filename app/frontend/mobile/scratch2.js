const fs=require('fs'); const txt=fs.readFileSync('lib/services/api_client.dart', 'utf8'); console.log(txt.split('\n').filter((l,i) => i>745 && i<770));
