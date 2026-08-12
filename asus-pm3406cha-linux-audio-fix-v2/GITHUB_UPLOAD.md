# Publish to GitHub

Create an empty GitHub repository, then from this directory:

```bash
git init
git add .
git commit -m "Initial PM3406CHA ALC256 Linux audio workaround v2"
git branch -M main
git remote add origin git@github.com:YOUR_USER/YOUR_REPO.git
git push -u origin main
```

Before public redistribution, choose and add the license you want for the repository.

Suggested repository name:

`asus-pm3406cha-linux-audio-fix`

Suggested description:

`Experimental Linux ALC256 speaker/headphone workaround for ASUS ExpertBook PM3406CHA (1043:3541), derived from same-device Windows codec state.`
