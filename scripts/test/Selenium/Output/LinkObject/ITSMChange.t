# --
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get selenium object
my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        # get helper object
        my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

        # get change state data
        my $ChangeStateDataRef = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemGet(
            Class => 'ITSM::ChangeManagement::Change::State',
            Name  => 'requested',
        );

        # get change object
        my $ChangeObject = $Kernel::OM->Get('Kernel::System::ITSMChange');

        # create test change
        my $ChangeTitleRandom = 'ITSMChange Requested ' . $Helper->GetRandomID();
        my $ChangeID          = $ChangeObject->ChangeAdd(
            ChangeTitle   => $ChangeTitleRandom,
            Description   => 'Selenium Test Description',
            Justification => 'Selenium Test Justification',
            ChangeStateID => $ChangeStateDataRef->{ItemID},
            UserID        => 1,
        );
        $Self->True(
            $ChangeID,
            "$ChangeTitleRandom is created",
        );

        # get ticket object
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        # create test ticket
        my $TicketNumber = $TicketObject->TicketCreateNumber();
        my $TicketID     = $TicketObject->TicketCreate(
            TN           => $TicketNumber,
            Title        => 'Selenium Test Ticket',
            Queue        => 'Raw',
            Lock         => 'unlock',
            Priority     => '3 normal',
            State        => 'open',
            CustomerID   => 'Test Selenium Customer',
            CustomerUser => 'Test Selenium Customer',
            OwnerID      => 1,
            UserID       => 1,
        );
        $Self->True(
            $TicketID,
            "Ticket ID $TicketID is created",
        );

        # create and log in test user
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => [ 'admin', 'users', 'itsm-change', 'itsm-change-builder', 'itsm-change-manager' ]
        ) || die "Did not get test user";

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        # get script alias
        my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');

        # navigate to AgentITSMChangeZoom of created test change
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentITSMChangeZoom;ChangeID=$ChangeID");

        # click on 'Link' and switch screens
        $Selenium->find_element("//a[contains(\@href, \'Action=AgentLinkObject;SourceObject=ITSMChange' )]")->click();

        $Selenium->WaitFor( WindowCount => 2 );
        my $Handles = $Selenium->get_window_handles();
        $Selenium->switch_to_window( $Handles->[1] );

        # wait until page has loaded, if necessary
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("#SubmitSearch").length' );

        # select test created ticket to link with test created change
        $Selenium->find_element("//input[\@name='SEARCH::TicketNumber']")->send_keys($TicketNumber);

        sleep(2);

        $Selenium->find_element("//button[\@value='Search'][\@type='submit']")->click();
        $Selenium->WaitFor( JavaScript => "return \$('input#LinkTargetKeys').length" );

        $Selenium->find_element("//input[\@id='LinkTargetKeys']")->click();
        $Selenium->find_element("//button[\@id='AddLinks'][\@type='submit']")->VerifiedClick();
        $Selenium->find_element( "#LinkAddCloseLink", 'css' )->click();

        $Selenium->WaitFor( WindowCount => 1 );
        $Selenium->switch_to_window( $Handles->[0] );

        sleep(2);

        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("body").length' );

        # verify test change is linked with test ticket
        $Self->True(
            index( $Selenium->get_page_source(), $TicketNumber ) > -1,
            "Test ticket number $TicketNumber is found",
        );

        # click on 'Link' and switch screens
        $Selenium->find_element("//a[contains(\@href, \'Action=AgentLinkObject;SourceObject=ITSMChange' )]")->click();

        $Selenium->WaitFor( WindowCount => 2 );
        $Handles = $Selenium->get_window_handles();
        $Selenium->switch_to_window( $Handles->[1] );

        # wait until page has loaded, if necessary
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("#SubmitSearch").length' );

        sleep(2);

        # delete link relation
        $Selenium->find_element("//a[\@href='#ManageLinks']")->click();
        $Selenium->find_element("//input[\@id='LinkDeleteIdentifier']")->click();
        $Selenium->find_element("//button[\@title='Delete links']")->VerifiedClick();

        $Selenium->find_element("//a[contains(\@href, \'Action=AgentLinkObject;Subaction=Close' )]")->click();

        $Selenium->WaitFor( WindowCount => 1 );
        $Selenium->switch_to_window( $Handles->[0] );

        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("body").length' );

        # verify that link has been removed
        $Self->True(
            index( $Selenium->get_page_source(), $TicketNumber ) == -1,
            "Test ticket number $TicketNumber is found",
        );

        # delete test created change
        my $Success = $ChangeObject->ChangeDelete(
            ChangeID => $ChangeID,
            UserID   => 1,
        );
        $Self->True(
            $Success,
            "$ChangeTitleRandom is deleted",
        );

        # delete test created ticket
        $Success = $TicketObject->TicketDelete(
            TicketID => $TicketID,
            UserID   => 1,
        );
        $Self->True(
            $Success,
            "Ticket ID $TicketID is deleted",
        );

        # make sure cache is correct
        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp( Type => 'ITSMChange*' );
    }
);

1;
