export COMMANDS='cat > /sources/archives/plasma-6.6.1.md5 << "EOF"
libksysguard-6.6.1.tar.xz
EOF
done < /sources/archives/plasma-6.6.1.md5'

export LFS_VERSION="6.6.1"
export UPSTREAM_FULL="6.6.4"

echo "$COMMANDS" | LFS_VERSION="$LFS_VERSION" UPSTREAM_FULL="$UPSTREAM_FULL" perl -0777 -pe '
    my $lv = $ENV{LFS_VERSION};
    my $uf = $ENV{UPSTREAM_FULL};
    s!((?:frameworks|plasma|breeze-icons|attica|extra-cmake-modules)-)$lv\.md5!${1}$uf.md5!g;
    s!(\/sources\/archives\/(?:frameworks|plasma|breeze-icons|attica|extra-cmake-modules)-)$lv\.md5!${1}$uf.md5!g;
    s!(cat > (?:/sources/archives/)?(?:frameworks|plasma|breeze-icons|attica|extra-cmake-modules)-$uf\.md5 << \"?EOF\"?\n)(.*?)(\nEOF)!
        do {
            my $header = $1;
            my $body = $2;
            my $footer = $3;
            $body =~ s/\Q$lv\E/$uf/g;
            $body =~ s/6\.\d+(?:\.\d+){0,2}/$uf/og;
            $header . $body . $footer
        }
    !gse;
    s!(done < (?:/sources/archives/)?(?:frameworks|plasma|breeze-icons|attica|extra-cmake-modules)-)$lv\.md5!${1}$uf.md5!g;
    s/\Q$lv\E/$uf/g;
'
