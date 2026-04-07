import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, fireEvent, act } from "@testing-library/react";
import { DesignProvider, DesignSwitch, useDesign } from "@/components/ui/DesignToggle";

// Mock localStorage
const localStorageMock = (() => {
  let store: Record<string, string> = {};
  return {
    getItem: vi.fn((key: string) => store[key] ?? null),
    setItem: vi.fn((key: string, value: string) => { store[key] = value; }),
    clear: () => { store = {}; },
  };
})();
Object.defineProperty(window, "localStorage", { value: localStorageMock });

function DesignReader() {
  const { design } = useDesign();
  return <div data-testid="design-value">{design}</div>;
}

describe("DesignToggle", () => {
  beforeEach(() => {
    localStorageMock.clear();
    document.documentElement.classList.remove("theme-v2");
  });

  it("defaults to classic design", () => {
    render(
      <DesignProvider>
        <DesignReader />
      </DesignProvider>
    );
    expect(screen.getByTestId("design-value")).toHaveTextContent("classic");
  });

  it("loads v2 from localStorage", () => {
    localStorageMock.getItem.mockReturnValueOnce("v2");
    render(
      <DesignProvider>
        <DesignReader />
      </DesignProvider>
    );
    expect(screen.getByTestId("design-value")).toHaveTextContent("v2");
  });

  it("toggles design and persists to localStorage", () => {
    render(
      <DesignProvider>
        <DesignReader />
        <DesignSwitch />
      </DesignProvider>
    );

    const button = screen.getByRole("button", { name: /try v2/i });
    expect(button).toBeInTheDocument();

    act(() => {
      fireEvent.click(button);
    });

    expect(screen.getByTestId("design-value")).toHaveTextContent("v2");
    expect(localStorageMock.setItem).toHaveBeenCalledWith("thc-design", "v2");
  });

  it("adds theme-v2 class to documentElement when v2 is active", () => {
    localStorageMock.getItem.mockReturnValueOnce("v2");
    render(
      <DesignProvider>
        <DesignReader />
      </DesignProvider>
    );
    expect(document.documentElement.classList.contains("theme-v2")).toBe(true);
  });

  it("removes theme-v2 class when toggled back to classic", () => {
    localStorageMock.getItem.mockReturnValueOnce("v2");
    render(
      <DesignProvider>
        <DesignReader />
        <DesignSwitch />
      </DesignProvider>
    );

    expect(document.documentElement.classList.contains("theme-v2")).toBe(true);

    // Toggle back — button should now say "Classic"
    const button = screen.getByRole("button", { name: /classic/i });
    act(() => {
      fireEvent.click(button);
    });

    expect(document.documentElement.classList.contains("theme-v2")).toBe(false);
    expect(screen.getByTestId("design-value")).toHaveTextContent("classic");
  });

  it("DesignSwitch shows 'Try v2' in classic mode and 'Classic' in v2 mode", () => {
    render(
      <DesignProvider>
        <DesignSwitch />
      </DesignProvider>
    );

    expect(screen.getByText("Try v2")).toBeInTheDocument();

    act(() => {
      fireEvent.click(screen.getByRole("button"));
    });

    expect(screen.getByText("Classic")).toBeInTheDocument();
  });
});
