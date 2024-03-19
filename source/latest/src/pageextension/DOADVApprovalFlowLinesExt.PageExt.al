namespace latest.latest;

pageextension 63030 "DOADV Approval Flow Lines Ext" extends "CDC Approval Flow Lines"
{
    layout
    {
        addlast(Group)
        {
            field("Notify User"; Rec."Notify User")
            {
                ApplicationArea = All;

            }
        }
    }
}
