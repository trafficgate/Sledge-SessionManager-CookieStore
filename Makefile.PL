use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'      => 'Sledge::SessionManager::CookieStore',
    'VERSION_FROM' => 'lib/Sledge/SessionManager/CookieStore.pm', # finds $VERSION
    'PREREQ_PM' => {
	Test::More => 0.32,
    },
);
