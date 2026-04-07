"use client";

import { useDesign } from "@/components/ui/DesignToggle";
import BottomTabs from "@/components/ui/BottomTabs";

export default function V2BottomTabs() {
  const { design } = useDesign();
  if (design !== "v2") return null;
  return <BottomTabs />;
}
